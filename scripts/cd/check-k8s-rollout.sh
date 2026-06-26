#!/usr/bin/env bash
set -euo pipefail

K8S_DEPLOYMENT="${K8S_DEPLOYMENT:?K8S_DEPLOYMENT is required}"
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"
EXPECTED_IMAGE="${EXPECTED_IMAGE:-${IMAGE_TAG:-}}"
IMAGE_WAIT_TIMEOUT_SECONDS="${IMAGE_WAIT_TIMEOUT_SECONDS:-600}"
IMAGE_WAIT_INTERVAL_SECONDS="${IMAGE_WAIT_INTERVAL_SECONDS:-10}"
POD_SELECTOR="${POD_SELECTOR:-app.kubernetes.io/instance=$K8S_DEPLOYMENT}"

if ! command -v kubectl >/dev/null 2>&1; then
  if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    echo "kubectl is required in GitHub Actions to verify rollout: $K8S_NAMESPACE/$K8S_DEPLOYMENT" >&2
    exit 127
  fi
  echo "kubectl is not installed. Dry-run for deployment: $K8S_NAMESPACE/$K8S_DEPLOYMENT"
  exit 0
fi

if [[ -n "$EXPECTED_IMAGE" ]]; then
  deadline=$((SECONDS + IMAGE_WAIT_TIMEOUT_SECONDS))
  while true; do
    current_images="$(kubectl -n "$K8S_NAMESPACE" get deploy "$K8S_DEPLOYMENT" -o jsonpath='{range .spec.template.spec.containers[*]}{.image}{"\n"}{end}')"
    if grep -Fxq "$EXPECTED_IMAGE" <<<"$current_images"; then
      echo "Deployment image matched expected image: $EXPECTED_IMAGE"
      break
    fi

    if ((SECONDS >= deadline)); then
      echo "Timed out waiting for deployment image to match expected image." >&2
      echo "Expected: $EXPECTED_IMAGE" >&2
      echo "Current images:" >&2
      echo "$current_images" >&2
      exit 1
    fi

    echo "Waiting for Argo CD/GitOps to apply expected image: $EXPECTED_IMAGE"
    sleep "$IMAGE_WAIT_INTERVAL_SECONDS"
  done
fi

kubectl -n "$K8S_NAMESPACE" rollout status "deployment/$K8S_DEPLOYMENT" --timeout "$ROLLOUT_TIMEOUT"
kubectl -n "$K8S_NAMESPACE" get deploy "$K8S_DEPLOYMENT"
kubectl -n "$K8S_NAMESPACE" get pods -l "$POD_SELECTOR"
