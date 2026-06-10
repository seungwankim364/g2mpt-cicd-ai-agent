#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-gympt-prod}"
DEPLOYMENT="${DEPLOYMENT:-backend-api-prod}"

echo "Runbook: BackendHighMemoryUsage"
echo "1. Check pod resource usage"
kubectl -n "$NAMESPACE" top pods -l "app=backend-api" || true

echo "2. Check pod restart/OOM symptoms"
kubectl -n "$NAMESPACE" describe pods -l "app=backend-api" |
  grep -Ei "OOMKilled|memory|restart|last state|reason" || true

echo "3. Check recent backend logs"
kubectl -n "$NAMESPACE" logs "deploy/$DEPLOYMENT" --tail=300 |
  grep -Ei "OutOfMemory|heap|memory|GC overhead|Metaspace" || true

echo "4. Recommended follow-up"
echo "- Open JVM Metrics dashboard"
echo "- Check heap/non-heap memory and GC panels"
echo "- Prefer manual fix or rollback after operator review"

