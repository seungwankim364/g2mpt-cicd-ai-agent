#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-prod}"

echo "[runbook] SQSDLQMessages"
echo "- Environment: $ENVIRONMENT"
echo "- Inspect DLQ sample messages and correlate with app logs/Athena errors."
echo "- Recommended action: open_fix_issue, then decide replay only after root cause is fixed."
