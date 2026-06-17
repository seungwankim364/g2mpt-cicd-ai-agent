#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-2}"

echo "[runbook] BedrockThrottling"
echo "- AWS region: $AWS_REGION"
echo "- Check Bedrock throttling, retry behavior, max token setting, and request volume."
echo "- Recommended action: open_fix_issue or reduce request pressure before retry."
