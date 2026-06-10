#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-}"
OUTPUT_FILE="${OUTPUT_FILE:-quality-gate-alerts.json}"
FIXTURE_FILE="${FIXTURE_FILE:-}"

usage() {
  cat <<'USAGE'
Usage:
  query-prometheus-alerts.sh

Environment:
  PROMETHEUS_URL  Prometheus base URL. Example: https://prometheus.example.com
  OUTPUT_FILE     Output JSON path. Default: quality-gate-alerts.json
  FIXTURE_FILE    Optional local fixture JSON path. If set, no network call is made.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -n "$FIXTURE_FILE" ]]; then
  cp "$FIXTURE_FILE" "$OUTPUT_FILE"
  echo "Wrote Prometheus alert fixture to $OUTPUT_FILE"
  exit 0
fi

if [[ -z "$PROMETHEUS_URL" ]]; then
  echo "PROMETHEUS_URL is required when FIXTURE_FILE is not set" >&2
  exit 2
fi

curl --fail --silent --show-error \
  "$PROMETHEUS_URL/api/v1/alerts" \
  --output "$OUTPUT_FILE"

echo "Wrote Prometheus alerts to $OUTPUT_FILE"

