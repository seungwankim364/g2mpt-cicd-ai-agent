#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-prod}"
DEPLOYMENT="${DEPLOYMENT:-backend-api}"

echo "Runbook: DBConnectionError"
kubectl -n "$NAMESPACE" logs "deploy/$DEPLOYMENT" --tail=300 | grep -Ei "db|database|connection|timeout|jdbc|postgres|mysql" || true
kubectl -n "$NAMESPACE" describe deploy "$DEPLOYMENT" | grep -Ei "DB_|DATABASE|SECRET|CONFIG" || true

