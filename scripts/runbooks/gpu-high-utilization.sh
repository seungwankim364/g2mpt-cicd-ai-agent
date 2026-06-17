#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-posture-analysis}"

echo "[runbook] GPUHighUtilization"
echo "- Namespace: $NAMESPACE"
echo "- Check posture-analysis GPU pods, queue depth, and batch size changes."
echo "- Recommended action: observe if transient, open_fix_issue if sustained."
