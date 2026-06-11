#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-backend-api}"
NAMESPACE="${NAMESPACE:-gympt-prod}"
ALERT_NAMES="${ALERT_NAMES:-BackendHighErrorRate,BackendHighLatency,BackendPodRestarting}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"
WINDOW_SECONDS="${HEALTH_CHECK_WINDOW_SECONDS:-300}"
INTERVAL_SECONDS="${HEALTH_CHECK_INTERVAL_SECONDS:-60}"
ALERT_FIXTURE_FILE="${ALERT_FIXTURE_FILE:-${FIXTURE_FILE:-}}"
METRICS_FIXTURE_FILE="${METRICS_FIXTURE_FILE:-}"

mkdir -p "$OUTPUT_DIR"

if ! [[ "$WINDOW_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "HEALTH_CHECK_WINDOW_SECONDS must be a non-negative integer" >&2
  exit 2
fi

if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_SECONDS" -eq 0 ]]; then
  echo "HEALTH_CHECK_INTERVAL_SECONDS must be a positive integer" >&2
  exit 2
fi

sample_count=1
if [[ "$WINDOW_SECONDS" -gt 0 ]]; then
  sample_count=$(( (WINDOW_SECONDS + INTERVAL_SECONDS - 1) / INTERVAL_SECONDS + 1 ))
fi

failed=0
sample_json_files=()

echo "Starting Quality Gate health check window: ${WINDOW_SECONDS}s, interval: ${INTERVAL_SECONDS}s, samples: ${sample_count}"

for sample in $(seq 1 "$sample_count"); do
  alerts_file="$OUTPUT_DIR/prometheus-alerts-${sample}.json"
  metrics_file="$OUTPUT_DIR/prometheus-metrics-${sample}.json"
  result_file="$OUTPUT_DIR/quality-gate-result-${sample}.json"

  echo "Health check sample ${sample}/${sample_count}: querying Prometheus alerts"
  FIXTURE_FILE="$ALERT_FIXTURE_FILE" OUTPUT_FILE="$alerts_file" scripts/quality-gate/query-prometheus-alerts.sh

  echo "Health check sample ${sample}/${sample_count}: querying Prometheus metrics"
  FIXTURE_FILE="$METRICS_FIXTURE_FILE" OUTPUT_FILE="$metrics_file" scripts/quality-gate/query-prometheus-metrics.sh

  echo "Health check sample ${sample}/${sample_count}: evaluating Quality Gate"
  if scripts/quality-gate/evaluate-quality-gate.py \
    --alerts-file "$alerts_file" \
    --service "$SERVICE_NAME" \
    --namespace "$NAMESPACE" \
    --alert-names "$ALERT_NAMES" \
    --output-file "$result_file"; then
    sample_status="passed"
  else
    sample_status="failed"
    failed=1
  fi

  sample_json_files+=("$result_file")

  cp "$alerts_file" "$OUTPUT_DIR/prometheus-alerts.json"
  cp "$metrics_file" "$OUTPUT_DIR/prometheus-metrics.json"
  cp "$result_file" "$OUTPUT_DIR/quality-gate-result.json"

  if [[ "$sample" -lt "$sample_count" ]]; then
    echo "Health check sample ${sample}/${sample_count} ${sample_status}. Waiting ${INTERVAL_SECONDS}s before next sample."
    sleep "$INTERVAL_SECONDS"
  fi
done

python3 - "$OUTPUT_DIR/quality-gate-window-result.json" "${sample_json_files[@]}" <<'PY'
import json
import sys
from pathlib import Path

output_file = Path(sys.argv[1])
sample_files = [Path(item) for item in sys.argv[2:]]
samples = []
matched_alerts = []

for index, sample_file in enumerate(sample_files, start=1):
    with sample_file.open("r", encoding="utf-8") as file:
        result = json.load(file)
    result["sample"] = index
    samples.append(result)
    for alert in result.get("matchedAlerts", []):
        alert_with_sample = dict(alert)
        alert_with_sample["sample"] = index
        matched_alerts.append(alert_with_sample)

window_result = {
    "service": samples[-1]["service"] if samples else None,
    "namespace": samples[-1]["namespace"] if samples else None,
    "status": "failed" if matched_alerts else "passed",
    "sampleCount": len(samples),
    "failedSampleCount": sum(1 for item in samples if item.get("status") == "failed"),
    "matchedAlertCount": len(matched_alerts),
    "matchedAlerts": matched_alerts,
    "samples": samples,
}

with output_file.open("w", encoding="utf-8") as file:
    json.dump(window_result, file, indent=2)
    file.write("\n")
PY

cp "$OUTPUT_DIR/quality-gate-window-result.json" "$OUTPUT_DIR/quality-gate-result.json"

if [[ "$failed" -eq 1 ]]; then
  echo "Quality Gate failed during health check window."
  exit 1
fi

echo "Quality Gate passed for the full health check window."
