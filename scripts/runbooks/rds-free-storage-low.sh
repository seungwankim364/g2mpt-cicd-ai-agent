#!/usr/bin/env bash
set -euo pipefail
echo "RDS free storage low: check storage growth, autovacuum, large tables/indexes, logs, and backup retention. Expand storage only after confirming growth source."
