#!/usr/bin/env bash
set -euo pipefail
echo "Lambda throttles high: check reserved concurrency, account concurrency, event source batch concurrency, and retry storm. Increase concurrency or slow producers after approval."
