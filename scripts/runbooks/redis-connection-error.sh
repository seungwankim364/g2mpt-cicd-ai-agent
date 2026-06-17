#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-prod}"

echo "[runbook] RedisConnectionError"
echo "- Environment: $ENVIRONMENT"
echo "- Check Redis endpoint, security group, DNS, connection pool, and recent app config changes."
echo "- Recommended action: open_fix_issue unless the failure is clearly deployment-specific rollback evidence."
