#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-2}"

echo "[runbook] BedrockHighErrorRate"
echo "- AWS region: $AWS_REGION"
echo "- Check Bedrock Runtime errors, IAM permissions, model id, and service quota events."
echo "- Recommended action: open_fix_issue; local ai-agent fallback should continue analysis."
