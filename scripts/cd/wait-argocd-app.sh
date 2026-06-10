#!/usr/bin/env bash
set -euo pipefail

ARGOCD_APP="${ARGOCD_APP:?ARGOCD_APP is required}"
ARGOCD_TIMEOUT="${ARGOCD_TIMEOUT:-300}"

if ! command -v argocd >/dev/null 2>&1; then
  echo "argocd CLI is not installed. Dry-run for app: $ARGOCD_APP"
  exit 0
fi

argocd app sync "$ARGOCD_APP" --timeout "$ARGOCD_TIMEOUT"
argocd app wait "$ARGOCD_APP" --health --sync --timeout "$ARGOCD_TIMEOUT"
argocd app get "$ARGOCD_APP"

