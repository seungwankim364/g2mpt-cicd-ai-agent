#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="${TMP_DIR:-/tmp/cd-quality-gate-local-test}"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

QUALITY_GATE_ALERT_NAMES="BackendHighErrorRate,BackendHighLatency,BackendPodRestarting,BackendDBPoolExhaustion,BackendHighMemoryUsage,SQSQueueBacklog,SQSMessageAge,SQSDLQMessages,NodeHighCPUUsage,PodRestartFrequent,GPUHighUtilization,GPUMemoryHigh,RedisConnectionError,RedisHighMemory,RedisHighEvictionRate,BedrockHighErrorRate,BedrockThrottling"
QUALITY_GATE_NAMESPACES="gympt-prod,monitoring,posture-analysis,elasticache"

echo "[1/9] Shell syntax"
bash -n scripts/cd/*.sh scripts/quality-gate/*.sh scripts/runbooks/*.sh scripts/aws/*.sh

echo "[2/9] Python compile"
python3 -m py_compile \
  scripts/quality-gate/*.py \
  lambda/analysis-orchestrator/*.py \
  lambda/slack-approval-handler/*.py \
  lambda/deployment-action-executor/*.py \
  lambda/github-webhook-handler/*.py \
  ai-agent/app/*.py

echo "[3/9] JSON fixtures and schemas"
python3 -m json.tool tests/fixtures/prometheus-alerts.normal.json >/dev/null
python3 -m json.tool tests/fixtures/prometheus-alerts.firing.json >/dev/null
python3 -m json.tool tests/fixtures/prometheus-metrics.sample.json >/dev/null
python3 -m json.tool tests/fixtures/deployment-failed.sample.json >/dev/null
python3 -m json.tool tests/fixtures/athena-summary.sample.json >/dev/null
python3 -m json.tool lambda/analysis-orchestrator/events/deployment-failed.sample.json >/dev/null
find schemas -name '*.json' -print0 | xargs -0 -I{} python3 -m json.tool {} >/dev/null

echo "[4/9] Quality Gate pass fixture"
FIXTURE_FILE=tests/fixtures/prometheus-alerts.normal.json \
OUTPUT_FILE="$TMP_DIR/prometheus-alerts-normal.json" \
scripts/quality-gate/query-prometheus-alerts.sh

scripts/quality-gate/evaluate-quality-gate.py \
  --alerts-file "$TMP_DIR/prometheus-alerts-normal.json" \
  --service backend-api \
  --namespace gympt-prod \
  --alert-names "$QUALITY_GATE_ALERT_NAMES" \
  --monitored-namespaces "$QUALITY_GATE_NAMESPACES" \
  --output-file "$TMP_DIR/quality-gate-result-normal.json"

ALERT_FIXTURE_FILE=tests/fixtures/prometheus-alerts.normal.json \
ALERT_NAMES="$QUALITY_GATE_ALERT_NAMES" \
MONITORED_NAMESPACES="$QUALITY_GATE_NAMESPACES" \
OUTPUT_DIR="$TMP_DIR/window-normal" \
HEALTH_CHECK_WINDOW_SECONDS=0 \
scripts/quality-gate/run-health-check-window.sh

echo "[5/9] Quality Gate fail fixture"
FIXTURE_FILE=tests/fixtures/prometheus-alerts.firing.json \
OUTPUT_FILE="$TMP_DIR/prometheus-alerts-firing.json" \
scripts/quality-gate/query-prometheus-alerts.sh

if scripts/quality-gate/evaluate-quality-gate.py \
  --alerts-file "$TMP_DIR/prometheus-alerts-firing.json" \
  --service backend-api \
  --namespace gympt-prod \
  --alert-names "$QUALITY_GATE_ALERT_NAMES" \
  --monitored-namespaces "$QUALITY_GATE_NAMESPACES" \
  --output-file "$TMP_DIR/quality-gate-result-firing.json"; then
  echo "Expected failing fixture to fail Quality Gate" >&2
  exit 1
fi

if ALERT_FIXTURE_FILE=tests/fixtures/prometheus-alerts.firing.json \
  ALERT_NAMES="$QUALITY_GATE_ALERT_NAMES" \
  MONITORED_NAMESPACES="$QUALITY_GATE_NAMESPACES" \
  OUTPUT_DIR="$TMP_DIR/window-firing" \
  HEALTH_CHECK_WINDOW_SECONDS=0 \
  scripts/quality-gate/run-health-check-window.sh; then
  echo "Expected failing fixture to fail Quality Gate health check window" >&2
  exit 1
fi

echo "[6/9] Slack payloads and EventBridge dry-run"
scripts/quality-gate/build-grafana-links.py \
  --base-url "https://grafana.g2mpt.com" \
  --dashboard-uid "api-latency" \
  --dashboard-uid "eks-overview" \
  --dashboard-uid "jvm-metrics" \
  --dashboard-uid "gpu-metrics" \
  --dashboard-uid "redis-metrics" \
  --dashboard-uid "sqs-metrics" \
  --service backend-api \
  --namespace gympt-prod \
  --prometheus-url "http://kube-prometheus-stack-prometheus.monitoring.svc:9090" \
  --argocd-url "https://argocd.g2mpt.com" \
  --argocd-app "backend-api-prod" \
  --output-file "$TMP_DIR/grafana-links.json"

SLACK_CHANNEL="#cd-deploy-alarm" scripts/quality-gate/send-slack-first-alert.py \
  --result-file "$TMP_DIR/quality-gate-result-firing.json" \
  --links-file "$TMP_DIR/grafana-links.json" \
  --output-file "$TMP_DIR/slack-first-alert.json" \
  --dry-run

SLACK_CHANNEL="#cd-deploy-alarm" scripts/quality-gate/send-slack-deploy-success.py \
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

DRY_RUN=true \
ACTION_TYPE=rollback \
DEPLOYMENT_ID=deploy-20260609-001 \
SERVICE_NAME=backend-api \
ENVIRONMENT=prod \
CURRENT_IMAGE_TAG=backend-api:failed \
TARGET_IMAGE_TAG=backend-api:stable \
APPROVED_BY=local-test \
REASON="fixture approval" \
OUTPUT_FILE="$TMP_DIR/deployment-action-approved-event.json" \
scripts/quality-gate/publish-approved-action-event.sh

echo "[7/9] Rollback target helpers"
fake_bin="$TMP_DIR/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/kubectl" <<'SH'
#!/usr/bin/env bash
cat <<'JSON'
{
  "items": [
    {
      "metadata": {
        "annotations": {"deployment.kubernetes.io/revision": "2"},
        "ownerReferences": [{"kind": "Deployment", "name": "backend-api-prod"}]
      },
      "spec": {"template": {"spec": {"containers": [{"image": "337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:200-badbad1"}]}}}
    },
    {
      "metadata": {
        "annotations": {"deployment.kubernetes.io/revision": "1"},
        "ownerReferences": [{"kind": "Deployment", "name": "backend-api-prod"}]
      },
      "spec": {"template": {"spec": {"containers": [{"image": "337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:199-good123"}]}}}
    }
  ]
}
JSON
SH
chmod +x "$fake_bin/kubectl"
previous_image="$(
  PATH="$fake_bin:$PATH" \
  K8S_DEPLOYMENT=backend-api-prod \
  K8S_NAMESPACE=gympt-prod \
  CURRENT_IMAGE=337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:200-badbad1 \
  scripts/cd/find-previous-k8s-image.sh
)"
test "$previous_image" = "337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:199-good123"

SERVICE_NAME=backend-api \
ENVIRONMENT=prod \
IMAGE_TAG="$previous_image" \
VALUES_FILE=charts/backend-api/values-prod.yaml \
scripts/cd/update-gitops-image-tag.sh >"$TMP_DIR/update-gitops-image-tag-dry-run.txt"
grep -q "Would update backend-api/prod image tag to 199-good123" "$TMP_DIR/update-gitops-image-tag-dry-run.txt"
grep -q "Normalized full image reference to tag" "$TMP_DIR/update-gitops-image-tag-dry-run.txt"

echo "[8/9] AI Agent and Lambda local execution"
PYTHONPATH=ai-agent python3 -m app.main \
  --input-file tests/fixtures/athena-summary.sample.json \
  --output-file "$TMP_DIR/ai-recommendation.json" \
  --slack-output-file "$TMP_DIR/slack-second-alert.json"

LOCAL_RESULT_DIR="$TMP_DIR/lambda-results" python3 lambda/analysis-orchestrator/app.py >/dev/null

GITHUB_WEBHOOK_SECRET=local-secret python3 - <<'PY'
import hashlib
import hmac
import importlib.util
import json

spec = importlib.util.spec_from_file_location("github_webhook", "lambda/github-webhook-handler/app.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

payload = {
    "action": "completed",
    "repository": {"full_name": "hj-3/gympt-app"},
    "workflow_run": {
        "name": "Backend API CI/CD",
        "conclusion": "success",
        "head_branch": "main",
        "head_sha": "5c35fc1abcd",
        "run_number": 115,
        "event": "push",
    },
}
raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
signature = "sha256=" + hmac.new(b"local-secret", raw, hashlib.sha256).hexdigest()
event = {"headers": {"X-GitHub-Event": "workflow_run", "X-Hub-Signature-256": signature}, "body": raw.decode("utf-8")}

allowed, checks = module._should_dispatch(payload)
assert allowed, checks
assert module._quality_gate_inputs(payload)["image_tag"].endswith(":115-5c35fc1")
assert module._verify_signature(module._headers(event), module._body(event))

payload["workflow_run"]["conclusion"] = "failure"
allowed, checks = module._should_dispatch(payload)
assert not allowed and not checks["conclusion"]
PY

echo "[9/9] AWS terraform destroy script help"
scripts/aws/destroy-terraform-stack.sh --help >/dev/null
node --check dashboard/src/main.js >/dev/null
node --check dashboard/server.mjs >/dev/null
node --check dashboard/src/data/loadDashboardData.js >/dev/null
node --check dashboard/src/data/sample-dashboard.js >/dev/null
python3 -m json.tool dashboard/data-contracts/dashboard-data.schema.json >/dev/null

echo "Local test passed. Artifacts: $TMP_DIR"
