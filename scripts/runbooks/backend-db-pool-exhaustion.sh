#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-gympt-prod}"
DEPLOYMENT="${DEPLOYMENT:-backend-api-prod}"

echo "Runbook: BackendDBPoolExhaustion"
echo "1. Check backend pods"
kubectl -n "$NAMESPACE" get pods -l "app=backend-api" || true

echo "2. Search DB pool related logs"
kubectl -n "$NAMESPACE" logs "deploy/$DEPLOYMENT" --tail=300 |
  grep -Ei "hikari|connection pool|database|jdbc|timeout|connection refused|connection reset" || true

echo "3. Check deployment env references"
kubectl -n "$NAMESPACE" describe deploy "$DEPLOYMENT" |
  grep -Ei "DB_|DATABASE|SPRING_DATASOURCE|SECRET|CONFIG" || true

echo "4. Recommended follow-up"
echo "- Open JVM Metrics dashboard"
echo "- Check hikaricp_connections_active / hikaricp_connections_max"
echo "- Review recent DB latency and connection timeout logs"

