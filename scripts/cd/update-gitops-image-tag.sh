#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:?SERVICE_NAME is required}"
ENVIRONMENT="${ENVIRONMENT:?ENVIRONMENT is required}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG is required}"
GITOPS_REPO="${GITOPS_REPO:-}"
VALUES_FILE="${VALUES_FILE:-}"

if [[ -z "$GITOPS_REPO" || -z "$VALUES_FILE" ]]; then
  echo "GITOPS_REPO or VALUES_FILE is not set. Dry-run only."
  echo "Would update $SERVICE_NAME/$ENVIRONMENT image tag to $IMAGE_TAG"
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

git clone "$GITOPS_REPO" "$workdir/repo"
cd "$workdir/repo"

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "VALUES_FILE not found: $VALUES_FILE" >&2
  exit 2
fi

sed -i.bak -E "s#(tag:[[:space:]]*).+#\\1${IMAGE_TAG}#" "$VALUES_FILE"
rm -f "$VALUES_FILE.bak"

git add "$VALUES_FILE"
git commit -m "deploy(${SERVICE_NAME}): update image tag to ${IMAGE_TAG}"
git push

git rev-parse HEAD

