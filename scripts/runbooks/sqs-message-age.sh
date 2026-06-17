#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-prod}"

echo "[runbook] SQSMessageAge"
echo "- Environment: $ENVIRONMENT"
echo "- Check oldest message age, consumer errors, and DLQ movement."
echo "- Recommended action: open_fix_issue before replaying or purging messages."
