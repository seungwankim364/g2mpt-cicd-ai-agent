#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-}"
OUTPUT_FILE="${OUTPUT_FILE:-prometheus-metrics.json}"
FIXTURE_FILE="${FIXTURE_FILE:-}"
SERVICE_NAME="${SERVICE_NAME:-backend-api}"
NAMESPACE="${NAMESPACE:-prod}"

if [[ -n "$FIXTURE_FILE" ]]; then
  cp "$FIXTURE_FILE" "$OUTPUT_FILE"
  echo "Wrote Prometheus metric fixture to $OUTPUT_FILE"
  exit 0
fi

if [[ -z "$PROMETHEUS_URL" ]]; then
  cat > "$OUTPUT_FILE" <<JSON
{
  "service": "$SERVICE_NAME",
  "namespace": "$NAMESPACE",
  "metrics": {
    "http5xxErrorRate": null,
    "p95LatencySeconds": null,
    "podRestartIncrease": null,
    "unavailableReplicas": null,
    "readinessProbeFailure": null
  },
  "source": "dry-run"
}
JSON
  echo "PROMETHEUS_URL is not set. Wrote dry-run metrics to $OUTPUT_FILE"
  exit 0
fi

query() {
  local name="$1"
  local promql="$2"
  curl --fail --silent --show-error \
    --get "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=$promql" |
    python3 -c 'import json,sys; data=json.load(sys.stdin); values=data.get("data",{}).get("result",[]); print(values[0]["value"][1] if values else "null")'
}

http5xx="$(query http5xx "sum(rate(http_requests_total{service=\"$SERVICE_NAME\",namespace=\"$NAMESPACE\",status=~\"5..\"}[5m]))")"
latency="$(query p95Latency "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service=\"$SERVICE_NAME\",namespace=\"$NAMESPACE\"}[5m])) by (le))")"
restarts="$(query podRestart "sum(increase(kube_pod_container_status_restarts_total{namespace=\"$NAMESPACE\"}[10m]))")"
unavailable="$(query unavailableReplicas "sum(kube_deployment_status_replicas_unavailable{namespace=\"$NAMESPACE\",deployment=\"$SERVICE_NAME\"})")"

cat > "$OUTPUT_FILE" <<JSON
{
  "service": "$SERVICE_NAME",
  "namespace": "$NAMESPACE",
  "metrics": {
    "http5xxErrorRate": $http5xx,
    "p95LatencySeconds": $latency,
    "podRestartIncrease": $restarts,
    "unavailableReplicas": $unavailable
  },
  "source": "prometheus"
}
JSON

echo "Wrote Prometheus metrics to $OUTPUT_FILE"

