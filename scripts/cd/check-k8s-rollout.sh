#!/usr/bin/env bash
set -euo pipefail

K8S_DEPLOYMENT="${K8S_DEPLOYMENT:?K8S_DEPLOYMENT is required}"
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"

if ! command -v kubectl >/dev/null 2>&1; then
  if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    echo "kubectl is required in GitHub Actions to verify rollout: $K8S_NAMESPACE/$K8S_DEPLOYMENT" >&2
    exit 127
  fi
  echo "kubectl is not installed. Dry-run for deployment: $K8S_NAMESPACE/$K8S_DEPLOYMENT"
  exit 0
fi

kubectl -n "$K8S_NAMESPACE" rollout status "deployment/$K8S_DEPLOYMENT" --timeout "$ROLLOUT_TIMEOUT"
kubectl -n "$K8S_NAMESPACE" get deploy "$K8S_DEPLOYMENT"
kubectl -n "$K8S_NAMESPACE" get pods -l "app=$K8S_DEPLOYMENT"
