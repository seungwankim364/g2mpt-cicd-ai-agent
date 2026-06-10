#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="${TMP_DIR:-/tmp/cd-quality-gate-local-test}"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "[1/8] Shell syntax"
bash -n scripts/cd/*.sh scripts/quality-gate/*.sh scripts/runbooks/*.sh scripts/aws/*.sh

echo "[2/8] Python compile"
python3 -m py_compile \
  scripts/quality-gate/*.py \
  lambda/analysis-orchestrator/*.py \
  ai-agent/app/*.py

echo "[3/8] JSON fixtures and schemas"
python3 -m json.tool tests/fixtures/prometheus-alerts.normal.json >/dev/null
python3 -m json.tool tests/fixtures/prometheus-alerts.firing.json >/dev/null
python3 -m json.tool tests/fixtures/prometheus-metrics.sample.json >/dev/null
python3 -m json.tool tests/fixtures/deployment-failed.sample.json >/dev/null
python3 -m json.tool tests/fixtures/athena-summary.sample.json >/dev/null
python3 -m json.tool lambda/analysis-orchestrator/events/deployment-failed.sample.json >/dev/null
find schemas -name '*.json' -print0 | xargs -0 -I{} python3 -m json.tool {} >/dev/null

echo "[4/8] Quality Gate pass fixture"
FIXTURE_FILE=tests/fixtures/prometheus-alerts.normal.json \
OUTPUT_FILE="$TMP_DIR/prometheus-alerts-normal.json" \
scripts/quality-gate/query-prometheus-alerts.sh

scripts/quality-gate/evaluate-quality-gate.py \
  --alerts-file "$TMP_DIR/prometheus-alerts-normal.json" \
  --service backend-api \
  --namespace gympt-prod \
  --alert-names BackendHighErrorRate,BackendHighLatency,BackendPodRestarting,BackendDBPoolExhaustion,BackendHighMemoryUsage \
  --output-file "$TMP_DIR/quality-gate-result-normal.json"

echo "[5/8] Quality Gate fail fixture"
FIXTURE_FILE=tests/fixtures/prometheus-alerts.firing.json \
OUTPUT_FILE="$TMP_DIR/prometheus-alerts-firing.json" \
scripts/quality-gate/query-prometheus-alerts.sh

if scripts/quality-gate/evaluate-quality-gate.py \
  --alerts-file "$TMP_DIR/prometheus-alerts-firing.json" \
  --service backend-api \
  --namespace gympt-prod \
  --alert-names BackendHighErrorRate,BackendHighLatency,BackendPodRestarting,BackendDBPoolExhaustion,BackendHighMemoryUsage \
  --output-file "$TMP_DIR/quality-gate-result-firing.json"; then
  echo "Expected failing fixture to fail Quality Gate" >&2
  exit 1
fi

echo "[6/8] Slack payloads and EventBridge dry-run"
scripts/quality-gate/build-grafana-links.py \
  --base-url "https://grafana.g2mpt.com" \
  --dashboard-uid "api-latency" \
  --service backend-api \
  --namespace gympt-prod \
  --output-file "$TMP_DIR/grafana-links.json"

SLACK_CHANNEL="#cicd-deploy-alarm" scripts/quality-gate/send-slack-first-alert.py \
  --result-file "$TMP_DIR/quality-gate-result-firing.json" \
  --links-file "$TMP_DIR/grafana-links.json" \
  --output-file "$TMP_DIR/slack-first-alert.json" \
  --dry-run

SLACK_CHANNEL="#cicd-deploy-alarm" scripts/quality-gate/send-slack-deploy-success.py \
  --service backend-api \
  --namespace gympt-prod \
  --image-tag fixture \
  --output-file "$TMP_DIR/slack-deploy-success.json" \
  --dry-run

DRY_RUN=true \
SERVICE_NAME=backend-api \
ENVIRONMENT=prod \
IMAGE_TAG=fixture \
QUALITY_GATE_RESULT_FILE="$TMP_DIR/quality-gate-result-firing.json" \
GRAFANA_LINKS_FILE="$TMP_DIR/grafana-links.json" \
OUTPUT_FILE="$TMP_DIR/deployment-failed-event.json" \
scripts/quality-gate/publish-eventbridge-event.sh

echo "[7/8] AI Agent and Lambda local execution"
PYTHONPATH=ai-agent python3 -m app.main \
  --input-file tests/fixtures/athena-summary.sample.json \
  --output-file "$TMP_DIR/ai-recommendation.json" \
  --slack-output-file "$TMP_DIR/slack-second-alert.json"

LOCAL_RESULT_DIR="$TMP_DIR/lambda-results" python3 lambda/analysis-orchestrator/app.py >/dev/null

echo "[8/8] AWS stop script help"
scripts/aws/stop-after-work.sh --help >/dev/null

echo "Local test passed. Artifacts: $TMP_DIR"

