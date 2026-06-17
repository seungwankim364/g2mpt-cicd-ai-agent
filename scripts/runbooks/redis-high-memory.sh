#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-prod}"

echo "[runbook] RedisHighMemory"
echo "- Environment: $ENVIRONMENT"
echo "- Check memory usage, eviction policy, hot keys, and cache TTL changes."
echo "- Recommended action: observe if transient, open_fix_issue for config/data review."
