#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-prod}"

echo "[runbook] SQSQueueBacklog"
echo "- Environment: $ENVIRONMENT"
echo "- Check queue consumers, worker pod health, and recent deployment changes."
echo "- Recommended action: open_fix_issue or scale the related consumer after review."
