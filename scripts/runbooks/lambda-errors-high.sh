#!/usr/bin/env bash
set -euo pipefail
echo "Lambda errors high: inspect CloudWatch Logs for exception type, recent code package, env vars, IAM errors, timeout, downstream API failures, and DLQ messages."
