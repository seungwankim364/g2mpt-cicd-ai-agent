#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-posture-analysis}"

echo "[runbook] GPUMemoryHigh"
echo "- Namespace: $NAMESPACE"
echo "- Check model memory growth, batch size, and pod restart history."
echo "- Recommended action: open_fix_issue before changing GPU workload settings."
