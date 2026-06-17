#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-prod}"

echo "[runbook] RedisHighEvictionRate"
echo "- Environment: $ENVIRONMENT"
echo "- Check eviction rate, maxmemory policy, cache key growth, and traffic changes."
echo "- Recommended action: open_fix_issue if eviction affects user traffic."
