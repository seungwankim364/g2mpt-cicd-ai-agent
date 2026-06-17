#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-gympt-prod}"

echo "[runbook] NodeHighCPUUsage"
echo "- Namespace: $NAMESPACE"
echo "- Check node pressure, HPA limits, pending pods, and recent traffic increase."
echo "- Recommended action: increase_hpa or scale capacity after confirming sustained pressure."
