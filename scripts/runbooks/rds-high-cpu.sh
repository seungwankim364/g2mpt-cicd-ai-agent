#!/usr/bin/env bash
set -euo pipefail
echo "RDS CPU high: check top SQL, active sessions, recent deploy traffic, slow queries, and read/write IOPS. If CPU stays high, scale instance class or reduce application concurrency after approval."
