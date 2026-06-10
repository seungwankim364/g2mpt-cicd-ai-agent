#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-prod}"
DEPLOYMENT="${DEPLOYMENT:-backend-api}"

echo "Runbook: BackendHighLatency"
kubectl -n "$NAMESPACE" top pods -l "app=$DEPLOYMENT" || true
kubectl -n "$NAMESPACE" logs "deploy/$DEPLOYMENT" --tail=200 | grep -Ei "slow|timeout|latency|duration" || true

