#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:?SERVICE_NAME is required}"
ENVIRONMENT="${ENVIRONMENT:?ENVIRONMENT is required}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG is required}"
GITOPS_REPO="${GITOPS_REPO:-hj-3/gympt-gitops}"
GITOPS_PAT="${GITOPS_PAT:-}"
VALUES_FILE="${VALUES_FILE:-}"
GITOPS_BASE_BRANCH="${GITOPS_BASE_BRANCH:-main}"
GITOPS_UPDATE_MODE="${GITOPS_UPDATE_MODE:-pr}"

normalize_image_tag() {
  local value="$1"
  if [[ "$value" == *"/"* && "$value" == *":"* ]]; then
    printf '%s\n' "${value##*:}"
    return
  fi
  printf '%s\n' "$value"
}

RAW_IMAGE_TAG="$IMAGE_TAG"
IMAGE_TAG="$(normalize_image_tag "$IMAGE_TAG")"

if [[ -z "$GITOPS_REPO" || -z "$VALUES_FILE" || -z "$GITOPS_PAT" ]]; then
  echo "GITOPS_REPO, GITOPS_PAT, or VALUES_FILE is not set. Dry-run only."
  echo "Would update $SERVICE_NAME/$ENVIRONMENT image tag to $IMAGE_TAG"
  if [[ "$RAW_IMAGE_TAG" != "$IMAGE_TAG" ]]; then
    echo "Normalized full image reference to tag: $RAW_IMAGE_TAG -> $IMAGE_TAG"
  fi
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

if command -v yq >/dev/null 2>&1; then
  IMAGE_TAG="$IMAGE_TAG" yq -i '.image.tag = strenv(IMAGE_TAG)' "$VALUES_FILE"
else
  sed -i.bak -E "s#(tag:[[:space:]]*).+#\\1${IMAGE_TAG}#" "$VALUES_FILE"
  rm -f "$VALUES_FILE.bak"
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

if git diff --quiet; then
  echo "No GitOps changes to commit"
  exit 0
fi

if [[ "$GITOPS_UPDATE_MODE" != "direct" ]]; then
  safe_tag="$(printf '%s' "$IMAGE_TAG" | tr -c '[:alnum:]._-' '-')"
  branch_name="cdqg/rollback-${SERVICE_NAME}-${ENVIRONMENT}-${safe_tag}-$(date -u +%Y%m%d%H%M%S)"
  git checkout -b "$branch_name"
fi

git add "$VALUES_FILE"
git commit -m "ci: update ${SERVICE_NAME} ${ENVIRONMENT} image to ${IMAGE_TAG}"

if [[ "$GITOPS_UPDATE_MODE" == "direct" ]]; then
  git pull --rebase origin "$GITOPS_BASE_BRANCH"
  git push origin "$GITOPS_BASE_BRANCH"
  git rev-parse HEAD
  exit 0
fi

git push origin "HEAD:${branch_name}"

pr_title="ci: rollback ${SERVICE_NAME} ${ENVIRONMENT} image to ${IMAGE_TAG}"
pr_body="$(cat <<EOF
Automated rollback request from cd-quality-gate.

- service: ${SERVICE_NAME}
- environment: ${ENVIRONMENT}
- values file: ${VALUES_FILE}
- image tag: ${IMAGE_TAG}

This repository uses protected main, so the rollback is proposed as a PR instead of pushing directly.
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
  echo "Failed to create GitOps rollback PR. HTTP ${status}" >&2
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
