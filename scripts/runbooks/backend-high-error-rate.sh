#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-prod}"
DEPLOYMENT="${DEPLOYMENT:-backend-api}"

echo "Runbook: BackendHighErrorRate"
echo "1. Check pods"
kubectl -n "$NAMESPACE" get pods -l "app=$DEPLOYMENT" || true
echo "2. Check deployment"
kubectl -n "$NAMESPACE" describe deploy "$DEPLOYMENT" || true
echo "3. Recent application logs"
kubectl -n "$NAMESPACE" logs "deploy/$DEPLOYMENT" --tail=200 || true

