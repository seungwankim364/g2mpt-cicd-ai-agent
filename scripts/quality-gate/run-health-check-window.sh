#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-backend-api}"
NAMESPACE="${NAMESPACE:-gympt-prod}"
ALERT_NAMES="${ALERT_NAMES:-BackendHighErrorRate,BackendHighLatency,BackendPodRestarting}"
MONITORED_NAMESPACES="${MONITORED_NAMESPACES:-$NAMESPACE}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"
WINDOW_SECONDS="${HEALTH_CHECK_WINDOW_SECONDS:-300}"
INTERVAL_SECONDS="${HEALTH_CHECK_INTERVAL_SECONDS:-60}"
ALERT_FIXTURE_FILE="${ALERT_FIXTURE_FILE:-${FIXTURE_FILE:-}}"
METRICS_FIXTURE_FILE="${METRICS_FIXTURE_FILE:-}"
CLOUDWATCH_FIXTURE_FILE="${CLOUDWATCH_FIXTURE_FILE:-}"
CLOUDWATCH_METRICS_FIXTURE_FILE="${CLOUDWATCH_METRICS_FIXTURE_FILE:-}"
CLOUDWATCH_ENABLED="${CLOUDWATCH_ENABLED:-true}"

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
  cloudwatch_file="$OUTPUT_DIR/cloudwatch-alarms-${sample}.json"
  cloudwatch_metrics_file="$OUTPUT_DIR/cloudwatch-metrics-${sample}.json"
  result_file="$OUTPUT_DIR/quality-gate-result-${sample}.json"

  echo "Health check sample ${sample}/${sample_count}: querying Prometheus alerts"
  FIXTURE_FILE="$ALERT_FIXTURE_FILE" OUTPUT_FILE="$alerts_file" scripts/quality-gate/query-prometheus-alerts.sh

  echo "Health check sample ${sample}/${sample_count}: querying Prometheus metrics"
  FIXTURE_FILE="$METRICS_FIXTURE_FILE" OUTPUT_FILE="$metrics_file" scripts/quality-gate/query-prometheus-metrics.sh

  cloudwatch_status="disabled"
  if [[ "$CLOUDWATCH_ENABLED" == "true" ]]; then
    echo "Health check sample ${sample}/${sample_count}: querying CloudWatch alarms"
    if python3 scripts/quality-gate/query-cloudwatch-alarms.py \
      --fixture-file "$CLOUDWATCH_FIXTURE_FILE" \
      --metric-fixture-file "$CLOUDWATCH_METRICS_FIXTURE_FILE" \
      --output-file "$cloudwatch_file" \
      --metric-output-file "$cloudwatch_metrics_file" \
      --window-seconds "$WINDOW_SECONDS"; then
      cloudwatch_status="passed"
    else
      cloudwatch_status="failed"
      failed=1
    fi
  else
    cat >"$cloudwatch_file" <<'JSON'
{"status":"disabled","summary":{"totalAlarmCount":0,"failingAlarmCount":0,"insufficientDataAlarmCount":0,"missingRegionCount":0},"regions":[],"failingAlarms":[],"insufficientDataAlarms":[],"missingRegions":[]}
JSON
    cat >"$cloudwatch_metrics_file" <<'JSON'
{"status":"disabled","datapoints":[]}
JSON
  fi

  echo "Health check sample ${sample}/${sample_count}: evaluating Quality Gate"
  prometheus_status="passed"
  if ! scripts/quality-gate/evaluate-quality-gate.py \
    --alerts-file "$alerts_file" \
    --service "$SERVICE_NAME" \
    --namespace "$NAMESPACE" \
    --alert-names "$ALERT_NAMES" \
    --monitored-namespaces "$MONITORED_NAMESPACES" \
    --output-file "$result_file"; then
    prometheus_status="failed"
    failed=1
  fi

  python3 - "$result_file" "$cloudwatch_file" "$cloudwatch_metrics_file" "$prometheus_status" "$cloudwatch_status" <<'PY'
import json
import sys
from pathlib import Path

result_path = Path(sys.argv[1])
cloudwatch_path = Path(sys.argv[2])
cloudwatch_metrics_path = Path(sys.argv[3])
prometheus_status = sys.argv[4]
cloudwatch_status = sys.argv[5]

result = json.loads(result_path.read_text(encoding="utf-8"))
cloudwatch = json.loads(cloudwatch_path.read_text(encoding="utf-8"))
cloudwatch_metrics = json.loads(cloudwatch_metrics_path.read_text(encoding="utf-8"))
result["prometheusStatus"] = prometheus_status
result["cloudWatchStatus"] = cloudwatch_status
result["cloudwatchAlarms"] = cloudwatch.get("failingAlarms", [])
result["cloudwatchInsufficientDataAlarms"] = cloudwatch.get("insufficientDataAlarms", [])
result["awsHealth"] = cloudwatch
result["awsMetricEvidence"] = cloudwatch_metrics
result["status"] = "failed" if prometheus_status == "failed" or cloudwatch_status == "failed" else "passed"
result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
PY

  sample_status="$(python3 - "$result_file" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("status", "unknown"))
PY
)"

  sample_json_files+=("$result_file")

  cp "$alerts_file" "$OUTPUT_DIR/prometheus-alerts.json"
  cp "$metrics_file" "$OUTPUT_DIR/prometheus-metrics.json"
  cp "$cloudwatch_file" "$OUTPUT_DIR/cloudwatch-alarms.json"
  cp "$cloudwatch_metrics_file" "$OUTPUT_DIR/cloudwatch-metrics.json"
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
cloudwatch_alarms = []
cloudwatch_insufficient = []
aws_health_samples = []
aws_metric_evidence_samples = []

for index, sample_file in enumerate(sample_files, start=1):
    with sample_file.open("r", encoding="utf-8") as file:
        result = json.load(file)
    result["sample"] = index
    samples.append(result)
    for alert in result.get("matchedAlerts", []):
        alert_with_sample = dict(alert)
        alert_with_sample["sample"] = index
        matched_alerts.append(alert_with_sample)
    for alarm in result.get("cloudwatchAlarms", []):
        alarm_with_sample = dict(alarm)
        alarm_with_sample["sample"] = index
        cloudwatch_alarms.append(alarm_with_sample)
    for alarm in result.get("cloudwatchInsufficientDataAlarms", []):
        alarm_with_sample = dict(alarm)
        alarm_with_sample["sample"] = index
        cloudwatch_insufficient.append(alarm_with_sample)
    aws_health = result.get("awsHealth")
    if aws_health:
        aws_health_samples.append({"sample": index, **aws_health})
    aws_metric_evidence = result.get("awsMetricEvidence")
    if aws_metric_evidence:
        aws_metric_evidence_samples.append({"sample": index, **aws_metric_evidence})

failed_samples = [item for item in samples if item.get("status") == "failed"]

window_result = {
    "service": samples[-1]["service"] if samples else None,
    "namespace": samples[-1]["namespace"] if samples else None,
    "status": "failed" if failed_samples else "passed",
    "sampleCount": len(samples),
    "failedSampleCount": len(failed_samples),
    "matchedAlertCount": len(matched_alerts),
    "matchedAlerts": matched_alerts,
    "cloudwatchAlarmCount": len(cloudwatch_alarms),
    "cloudwatchAlarms": cloudwatch_alarms,
    "cloudwatchInsufficientDataAlarmCount": len(cloudwatch_insufficient),
    "cloudwatchInsufficientDataAlarms": cloudwatch_insufficient,
    "awsHealth": aws_health_samples[-1] if aws_health_samples else None,
    "awsHealthSamples": aws_health_samples,
    "awsMetricEvidence": aws_metric_evidence_samples[-1] if aws_metric_evidence_samples else None,
    "awsMetricEvidenceSamples": aws_metric_evidence_samples,
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
