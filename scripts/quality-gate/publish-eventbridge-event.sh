#!/usr/bin/env bash
set -euo pipefail

EVENT_BUS_NAME="${EVENT_BUS_NAME:-default}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
SERVICE_NAME="${SERVICE_NAME:-backend-api}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
IMAGE_TAG="${IMAGE_TAG:-unknown}"
COMMIT_SHA="${GITHUB_SHA:-unknown}"
QUALITY_GATE_RESULT_FILE="${QUALITY_GATE_RESULT_FILE:-quality-gate-result.json}"
GRAFANA_LINKS_FILE="${GRAFANA_LINKS_FILE:-grafana-links.json}"
OUTPUT_FILE="${OUTPUT_FILE:-deployment-failed-event.json}"
DRY_RUN="${DRY_RUN:-false}"

python3 - "$QUALITY_GATE_RESULT_FILE" "$GRAFANA_LINKS_FILE" "$OUTPUT_FILE" "$SERVICE_NAME" "$ENVIRONMENT" "$IMAGE_TAG" "$COMMIT_SHA" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

result_path, links_path, output_path, service, environment, image_tag, commit_sha = sys.argv[1:]
result = json.loads(Path(result_path).read_text(encoding="utf-8"))
links = json.loads(Path(links_path).read_text(encoding="utf-8")) if Path(links_path).exists() else {}
now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
event = {
    "source": "cd.quality-gate",
    "detail-type": "DeploymentFailed",
    "time": now,
    "detail": {
        "deploymentId": f"{service}-{environment}-{now}",
        "service": service,
        "environment": environment,
        "repository": "unknown",
        "commitSha": commit_sha,
        "imageTag": image_tag,
        "argocdApp": f"{service}-{environment}",
        "failedAt": now,
        "alerts": result.get("matchedAlerts", []),
        "grafanaLinks": links.get("grafana", {}),
        "qualityGateResult": result,
    },
}
Path(output_path).write_text(json.dumps(event, indent=2) + "\n", encoding="utf-8")
PY

if [[ "$DRY_RUN" == "true" || -z "${EVENT_BUS_NAME:-}" ]]; then
  echo "Wrote EventBridge event payload to $OUTPUT_FILE"
  exit 0
fi

aws events put-events \
  --region "$AWS_REGION" \
  --entries "Source=cd.quality-gate,DetailType=DeploymentFailed,EventBusName=${EVENT_BUS_NAME},Detail=$(jq -c '.detail' "$OUTPUT_FILE")"

echo "Published DeploymentFailed event to EventBridge"

