#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-prod}"
DEPLOYMENT="${DEPLOYMENT:-backend-api}"

echo "Runbook: BackendPodRestarting"
kubectl -n "$NAMESPACE" get pods -l "app=$DEPLOYMENT" || true
kubectl -n "$NAMESPACE" describe pods -l "app=$DEPLOYMENT" || true
kubectl -n "$NAMESPACE" logs "deploy/$DEPLOYMENT" --previous --tail=200 || true
kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp | tail -50 || true

