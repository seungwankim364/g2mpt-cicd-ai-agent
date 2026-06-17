#!/usr/bin/env bash
set -euo pipefail

EVENT_BUS_NAME="${EVENT_BUS_NAME:-cd-quality-gate-prod-bus}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
ACTION_TYPE="${ACTION_TYPE:-}"
DEPLOYMENT_ID="${DEPLOYMENT_ID:-}"
SERVICE_NAME="${SERVICE_NAME:-backend-api}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
APPROVED_BY="${APPROVED_BY:-unknown}"
REASON="${REASON:-}"
CURRENT_IMAGE_TAG="${CURRENT_IMAGE_TAG:-unknown}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-}"
OUTPUT_FILE="${OUTPUT_FILE:-deployment-action-approved-event.json}"
DRY_RUN="${DRY_RUN:-false}"

case "$ACTION_TYPE" in
  rollback|manual_fix|change|restart_deployment|scale_replicas|increase_memory|increase_hpa|open_fix_issue|open_change_pr)
    ;;
  *)
    echo "ACTION_TYPE must be one of: rollback, manual_fix, change, restart_deployment, scale_replicas, increase_memory, increase_hpa, open_fix_issue, open_change_pr" >&2
    exit 2
    ;;
esac

if [[ -z "$DEPLOYMENT_ID" ]]; then
  echo "DEPLOYMENT_ID is required" >&2
  exit 2
fi

python3 - "$OUTPUT_FILE" "$ACTION_TYPE" "$DEPLOYMENT_ID" "$SERVICE_NAME" "$ENVIRONMENT" "$APPROVED_BY" "$REASON" "$CURRENT_IMAGE_TAG" "$TARGET_IMAGE_TAG" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

(
    output_path,
    action_type,
    deployment_id,
    service,
    environment,
    approved_by,
    reason,
    current_image_tag,
    target_image_tag,
) = sys.argv[1:]

now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
event = {
    "source": "cd.quality-gate",
    "detail-type": "DeploymentActionApproved",
    "time": now,
    "detail": {
        "deploymentId": deployment_id,
        "service": service,
        "environment": environment,
        "actionType": action_type,
        "approvedBy": approved_by,
        "approvedAt": now,
        "reason": reason,
        "currentImageTag": current_image_tag,
        "targetImageTag": target_image_tag,
        "status": "approved",
    },
}
Path(output_path).write_text(json.dumps(event, indent=2) + "\n", encoding="utf-8")
PY

if [[ "$DRY_RUN" == "true" || -z "${EVENT_BUS_NAME:-}" ]]; then
  echo "Wrote approved action event payload to $OUTPUT_FILE"
  exit 0
fi

entries_file="$(mktemp)"
trap 'rm -f "$entries_file"' EXIT
python3 - "$OUTPUT_FILE" "$EVENT_BUS_NAME" "$entries_file" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
entry = {
    "Source": "cd.quality-gate",
    "DetailType": "DeploymentActionApproved",
    "EventBusName": sys.argv[2],
    "Detail": json.dumps(payload["detail"], separators=(",", ":")),
}
Path(sys.argv[3]).write_text(json.dumps([entry], separators=(",", ":")), encoding="utf-8")
PY

aws events put-events \
  --region "$AWS_REGION" \
  --entries "file://${entries_file}"

echo "Published DeploymentActionApproved event to EventBridge"
