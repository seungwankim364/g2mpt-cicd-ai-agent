#!/usr/bin/env bash
set -euo pipefail

GITOPS_REPO="${GITOPS_REPO:-hj-3/gympt-gitops}"
GITOPS_PAT="${GITOPS_PAT:-}"
VALUES_FILE="${VALUES_FILE:?VALUES_FILE is required}"
YAML_PATH="${YAML_PATH:?YAML_PATH is required}"
YAML_VALUE="${YAML_VALUE:?YAML_VALUE is required}"
YAML_VALUE_TYPE="${YAML_VALUE_TYPE:-string}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-ci: update ${VALUES_FILE} ${YAML_PATH}}"
GITOPS_BASE_BRANCH="${GITOPS_BASE_BRANCH:-main}"
GITOPS_UPDATE_MODE="${GITOPS_UPDATE_MODE:-pr}"

if [[ -z "$GITOPS_REPO" || -z "$GITOPS_PAT" ]]; then
  echo "GITOPS_REPO or GITOPS_PAT is not set. Dry-run only."
  echo "Would update ${VALUES_FILE}: ${YAML_PATH}=${YAML_VALUE}"
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

if [[ "$GITOPS_REPO" == https://* || "$GITOPS_REPO" == git@* ]]; then
  clone_url="$GITOPS_REPO"
else
  clone_url="https://x-access-token:${GITOPS_PAT}@github.com/${GITOPS_REPO}.git"
fi

git clone "$clone_url" "$workdir/repo"
cd "$workdir/repo"

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "VALUES_FILE not found: $VALUES_FILE" >&2
  exit 2
fi

python3 - "$VALUES_FILE" "$YAML_PATH" "$YAML_VALUE" "$YAML_VALUE_TYPE" <<'PY'
import re
import sys
from pathlib import Path

path, yaml_path, raw_value, value_type = sys.argv[1:]
keys = yaml_path.split(".")
file_path = Path(path)
lines = file_path.read_text(encoding="utf-8").splitlines()


def key_name(line):
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or ":" not in stripped:
        return None
    return stripped.split(":", 1)[0].strip().strip('"').strip("'")


def indent(line):
    return len(line) - len(line.lstrip(" "))


def scalar(value, kind):
    if kind == "number":
        return value
    if kind == "bool":
        return "true" if value.lower() in {"1", "true", "yes", "on"} else "false"
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def block_end(start_index, current_indent):
    index = start_index + 1
    while index < len(lines):
        if lines[index].strip() and indent(lines[index]) <= current_indent:
            break
        index += 1
    return index


def find_key(start, end, target_indent, target_key):
    for index in range(start, end):
        if indent(lines[index]) == target_indent and key_name(lines[index]) == target_key:
            return index
    return None


def ensure_path(start, end, current_indent, remaining):
    current_key = remaining[0]
    found = find_key(start, end, current_indent, current_key)

    if len(remaining) == 1:
        new_line = f"{' ' * current_indent}{current_key}: {scalar(raw_value, value_type)}"
        if found is None:
            lines.insert(end, new_line)
        else:
            lines[found] = new_line
        return

    if found is None:
        insert_at = end
        lines.insert(insert_at, f"{' ' * current_indent}{current_key}:")
        found = insert_at
        end = found + 1

    child_indent = current_indent + 2
    ensure_path(found + 1, block_end(found, current_indent), child_indent, remaining[1:])


ensure_path(0, len(lines), 0, keys)
file_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
PY

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

if git diff --quiet; then
  echo "No GitOps changes to commit"
  exit 0
fi

if [[ "$GITOPS_UPDATE_MODE" != "direct" ]]; then
  safe_path="$(printf '%s' "$YAML_PATH" | tr -c '[:alnum:]._-' '-')"
  branch_name="cdqg/change-${safe_path}-$(date -u +%Y%m%d%H%M%S)"
  git checkout -b "$branch_name"
fi

git add "$VALUES_FILE"
git commit -m "$COMMIT_MESSAGE"

if [[ "$GITOPS_UPDATE_MODE" == "direct" ]]; then
  git pull --rebase origin "$GITOPS_BASE_BRANCH"
  git push origin "$GITOPS_BASE_BRANCH"
  git rev-parse HEAD
  exit 0
fi

git push origin "HEAD:${branch_name}"

pr_title="$COMMIT_MESSAGE"
pr_body="$(cat <<EOF
Automated approved change request from cd-quality-gate.

- values file: ${VALUES_FILE}
- yaml path: ${YAML_PATH}
- yaml value: ${YAML_VALUE}
- value type: ${YAML_VALUE_TYPE}

This repository uses protected main, so the approved change is proposed as a PR instead of pushing directly.
EOF
)"

python3 - "$pr_title" "$branch_name" "$GITOPS_BASE_BRANCH" "$pr_body" > /tmp/gitops-pr-payload.json <<'PY'
import json
import sys

title, head, base, body = sys.argv[1:]
print(json.dumps({"title": title, "head": head, "base": base, "body": body}))
PY

status="$(curl -sS -o /tmp/gitops-pr.json -w "%{http_code}" \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITOPS_PAT}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${GITOPS_REPO}/pulls" \
  -d @/tmp/gitops-pr-payload.json)"

if [[ "$status" != "201" ]]; then
  echo "Failed to create GitOps change PR. HTTP ${status}" >&2
  cat /tmp/gitops-pr.json >&2
  exit 1
fi

python3 - <<'PY'
import json

with open("/tmp/gitops-pr.json", encoding="utf-8") as f:
    pr = json.load(f)
print(f"Created GitOps PR: {pr['html_url']}")
PY

git rev-parse HEAD
