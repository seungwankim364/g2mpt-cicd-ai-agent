#!/usr/bin/env bash
set -euo pipefail
echo "RDS latency high: compare read/write latency, IOPS, CPU, locks, and slow queries. Roll back if latency started immediately after deploy."
