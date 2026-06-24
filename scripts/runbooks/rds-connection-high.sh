#!/usr/bin/env bash
set -euo pipefail
echo "RDS connections high: check backend DB pool metrics, connection leaks, Hikari pool usage, idle sessions, and recent pod scale-out. Prefer fixing pool leak or limiting replicas before increasing max_connections."
