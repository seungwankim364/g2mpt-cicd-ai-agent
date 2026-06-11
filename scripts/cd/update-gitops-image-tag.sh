#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:?SERVICE_NAME is required}"
ENVIRONMENT="${ENVIRONMENT:?ENVIRONMENT is required}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG is required}"
GITOPS_REPO="${GITOPS_REPO:-hj-3/gympt-gitops}"
GITOPS_PAT="${GITOPS_PAT:-}"
VALUES_FILE="${VALUES_FILE:-}"

if [[ -z "$GITOPS_REPO" || -z "$VALUES_FILE" || -z "$GITOPS_PAT" ]]; then
  echo "GITOPS_REPO, GITOPS_PAT, or VALUES_FILE is not set. Dry-run only."
  echo "Would update $SERVICE_NAME/$ENVIRONMENT image tag to $IMAGE_TAG"
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

git add "$VALUES_FILE"
git commit -m "ci: update ${SERVICE_NAME} ${ENVIRONMENT} image to ${IMAGE_TAG}"
git pull --rebase origin main
git push origin main

git rev-parse HEAD
