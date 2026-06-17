import json
import os
import time
from decimal import Decimal

try:
    import boto3
except ImportError:
    boto3 = None


EVENT_BUS_NAME = os.environ.get("EVENT_BUS_NAME", "")
ACTION_TABLE_NAME = os.environ.get("ACTION_TABLE_NAME", "")
RESULT_BUCKET = os.environ.get("RESULT_BUCKET", "")
ALLOWED_ACTIONS = {
    "rollback",
    "manual_fix",
    "change",
    "restart_deployment",
    "scale_replicas",
    "increase_memory",
    "increase_hpa",
    "open_fix_issue",
    "open_change_pr",
}


def _json_response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "content-type",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        },
        "body": json.dumps(body, default=_json_default),
    }


def _json_default(value):
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def _body(event):
    return json.loads(event.get("body") or "{}")


def _route(event):
    method = event.get("requestContext", {}).get("http", {}).get("method") or event.get("httpMethod", "GET")
    path = event.get("rawPath") or event.get("path", "/")
    return method.upper(), path


def _ddb_table():
    if boto3 is None or not ACTION_TABLE_NAME:
        return None
    return boto3.resource("dynamodb").Table(ACTION_TABLE_NAME)


def _eventbridge():
    if boto3 is None or not EVENT_BUS_NAME:
        return None
    return boto3.client("events")


def _s3():
    if boto3 is None or not RESULT_BUCKET:
        return None
    return boto3.client("s3")


def _list_actions():
    table = _ddb_table()
    if table is None:
        return []
    response = table.scan(Limit=50)
    items = response.get("Items", [])
    return sorted(items, key=lambda item: item.get("createdAt", ""), reverse=True)


def _put_action(record):
    table = _ddb_table()
    if table is not None:
        table.put_item(Item=record)


def _publish_approved_action(detail):
    events = _eventbridge()
    if events is None:
        return {"status": "dry-run"}
    return events.put_events(
        Entries=[
            {
                "Source": "cd.quality-gate",
                "DetailType": "DeploymentActionApproved",
                "EventBusName": EVENT_BUS_NAME,
                "Detail": json.dumps(detail),
            }
        ]
    )


def _base_dashboard():
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    return {
        "mode": "aws-dashboard",
        "generatedAt": now,
        "deployment": {
            "id": "backend-api-prod",
            "service": "backend-api",
            "environment": "prod",
            "namespace": "gympt-prod",
            "imageTag": "unknown",
            "rollbackImageTag": "",
            "commitSha": "",
            "branch": "main",
            "repository": "hj-3/gympt-app",
            "argocdApp": "backend-api-prod",
            "status": "waiting",
            "startedAt": "",
            "lastUpdatedAt": now,
        },
        "timeline": [
            {"id": "push", "label": "GitHub push", "owner": "gympt-app", "status": "waiting", "at": "-", "detail": "Waiting for backend-api workflow."},
            {"id": "gitops", "label": "GitOps update", "owner": "gympt-gitops", "status": "waiting", "at": "-", "detail": "Waiting for values-prod.yaml image tag update."},
            {"id": "argocd", "label": "Argo CD sync", "owner": "Argo CD", "status": "waiting", "at": "-", "detail": "Open Argo CD link for live sync/health."},
            {"id": "gate", "label": "Quality Gate", "owner": "cd-quality-gate", "status": "waiting", "at": "-", "detail": "Waiting for 5 minute health window result."},
            {"id": "approval", "label": "Approval action", "owner": "Slack/Dashboard", "status": "pending", "at": "-", "detail": "Rollback/fix/change approval is not yet recorded."},
        ],
        "healthWindow": {
            "durationSeconds": 300,
            "intervalSeconds": 60,
            "result": "waiting",
            "samples": [],
            "metrics": {
                "errorRate": 0,
                "p95LatencySeconds": 0,
                "dbPoolUsageRatio": 0,
                "jvmHeapUsageRatio": 0,
            },
        },
        "alertGroups": [],
        "links": {
            "grafana": "https://grafana.g2mpt.com",
            "prometheus": "http://kube-prometheus-stack-prometheus.monitoring.svc:9090",
            "argocd": "https://argocd.g2mpt.com/applications/backend-api-prod",
            "githubRun": "https://github.com/hj-3/gympt-app/actions/workflows/backend-api-ci.yml",
            "slackChannel": "#cd-deploy-alarm",
        },
        "analysis": {
            "engine": "Amazon Bedrock / local fallback",
            "model": "anthropic.claude-3-haiku-20240307-v1:0",
            "confidence": 0,
            "recommendedAction": "observe",
            "severity": "info",
            "summary": "No failed deployment analysis has been loaded yet.",
            "causeCandidates": [],
            "nextSteps": ["Run service deployment", "Wait for Quality Gate", "Review Slack analysis if Quality Gate fails"],
        },
        "approvals": [
            {"action": "rollback", "status": "available", "target": "previous image tag", "workflow": "rollback.yml"},
            {"action": "restart_deployment", "status": "available", "target": "pod annotation bump", "workflow": "change-apply.yml"},
            {"action": "scale_replicas", "status": "available", "target": "autoscaling.minReplicas", "workflow": "change-apply.yml"},
            {"action": "increase_memory", "status": "available", "target": "memory request/limit", "workflow": "change-apply.yml"},
            {"action": "increase_hpa", "status": "available", "target": "autoscaling.maxReplicas", "workflow": "change-apply.yml"},
            {"action": "open_fix_issue", "status": "available", "target": "fix issue", "workflow": "manual-fix.yml"},
            {"action": "open_change_pr", "status": "available", "target": "change issue", "workflow": "change-apply.yml"},
        ],
        "infra": {
            "terraformState": "applied",
            "resources": [
                {"name": "Lambda", "status": "available", "count": 4},
                {"name": "EventBridge", "status": "available", "count": 3},
                {"name": "S3 result bucket", "status": "available", "count": 1},
                {"name": "Athena", "status": "available", "count": 2},
                {"name": "API Gateway", "status": "available", "count": 1},
            ],
            "checklist": [
                {"label": "Dashboard API reachable", "status": "complete"},
                {"label": "Prometheus/Grafana/Argo CD/GitHub links configured", "status": "complete"},
                {"label": "Slack approvals publish EventBridge events", "status": "complete"},
                {"label": "Live service Quality Gate run", "status": "pending"},
            ],
        },
    }


def _latest_analysis_summary():
    s3 = _s3()
    if s3 is None:
        return None
    response = s3.list_objects_v2(Bucket=RESULT_BUCKET, Prefix="deployment-failures/")
    candidates = [
        item for item in response.get("Contents", []) if item.get("Key", "").endswith("/athena-summary.json")
    ]
    if not candidates:
        return None
    latest = sorted(candidates, key=lambda item: item.get("LastModified"))[-1]
    body = s3.get_object(Bucket=RESULT_BUCKET, Key=latest["Key"])["Body"].read().decode("utf-8")
    return json.loads(body)


def _apply_latest_analysis(dashboard):
    summary = _latest_analysis_summary()
    if not summary:
        return dashboard
    alerts = summary.get("alerts", [])
    dashboard["deployment"].update(
        {
            "id": summary.get("deploymentId", dashboard["deployment"]["id"]),
            "service": summary.get("service", dashboard["deployment"]["service"]),
            "environment": summary.get("environment", dashboard["deployment"]["environment"]),
            "imageTag": summary.get("imageTag", dashboard["deployment"]["imageTag"]),
            "rollbackImageTag": summary.get("rollbackImageTag", dashboard["deployment"]["rollbackImageTag"]),
            "status": "failed" if alerts else "complete",
            "lastUpdatedAt": summary.get("failedAt", dashboard["deployment"]["lastUpdatedAt"]),
        }
    )
    dashboard["alertGroups"] = [
        {
            "name": "Quality Gate",
            "severity": "critical" if alerts else "available",
            "count": len(alerts),
            "dashboards": list((summary.get("grafanaLinks") or {}).keys()),
            "alerts": [
                {
                    "name": alert.get("alertName") or alert.get("labels", {}).get("alertname", "unknown"),
                    "severity": alert.get("severity") or alert.get("labels", {}).get("severity", "unknown"),
                    "summary": alert.get("summary") or alert.get("annotations", {}).get("summary", ""),
                    "value": str(alert.get("value", "")),
                }
                for alert in alerts
            ],
        }
    ]
    dashboard["analysis"]["summary"] = "Latest failed deployment analysis summary is loaded from S3."
    dashboard["analysis"]["confidence"] = 0.5 if alerts else 0
    dashboard["timeline"] = [
        {**item, "status": "failed" if item["id"] == "gate" and alerts else item["status"]}
        for item in dashboard["timeline"]
    ]
    return dashboard


def _dashboard():
    actions = _list_actions()
    dashboard = _apply_latest_analysis(_base_dashboard())
    dashboard["system"] = {
        "backend": {"status": "connected", "api": "dashboard-api-lambda"},
        "database": {"status": "connected", "type": "dynamodb", "records": len(actions)},
        "eventBridge": {"status": "connected" if EVENT_BUS_NAME else "unavailable", "bus": EVENT_BUS_NAME},
        "resultBucket": {"status": "connected" if RESULT_BUCKET else "unavailable", "bucket": RESULT_BUCKET},
        "prometheus": {"status": "linked", "url": dashboard["links"]["prometheus"]},
        "grafana": {"status": "linked", "url": dashboard["links"]["grafana"]},
        "argocd": {"status": "linked", "url": dashboard["links"]["argocd"]},
        "githubActions": {"status": "linked", "url": dashboard["links"]["githubRun"]},
        "slack": {"status": "linked", "channel": dashboard["links"]["slackChannel"]},
    }
    dashboard["actionHistory"] = actions
    dashboard["latestAction"] = actions[0] if actions else None
    return dashboard


def _create_action(payload):
    now = int(time.time())
    action_type = payload.get("actionType") or payload.get("action")
    if not action_type:
        return _json_response(400, {"error": "actionType is required"})
    if action_type not in ALLOWED_ACTIONS:
        return _json_response(400, {"error": f"actionType must be one of {', '.join(sorted(ALLOWED_ACTIONS))}"})

    approved_at = payload.get("approvedAt", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)))
    detail = {
        "deploymentId": payload.get("deploymentId", "unknown-deployment"),
        "service": payload.get("service", "backend-api"),
        "environment": payload.get("environment", "prod"),
        "actionType": action_type,
        "approvedBy": payload.get("approvedBy", "dashboard"),
        "approvedAt": approved_at,
        "reason": payload.get("reason", "approved from dashboard"),
        "currentImageTag": payload.get("currentImageTag", "unknown"),
        "targetImageTag": payload.get("targetImageTag", ""),
        "status": "approved",
    }
    record = {
        "id": f"act-{now}",
        "createdAt": approved_at,
        "actionType": action_type,
        "status": "approved",
        "detail": detail,
    }
    _put_action(record)
    return _json_response(201, {"record": record, "eventBridge": _publish_approved_action(detail)})


def handler(event, context):
    method, path = _route(event)
    if method == "OPTIONS":
        return _json_response(204, {})
    if method == "GET" and path in {"/dashboard", "/api/dashboard"}:
        return _json_response(200, _dashboard())
    if method == "GET" and path in {"/actions", "/api/actions"}:
        return _json_response(200, {"actions": _list_actions()})
    if method == "POST" and path in {"/actions", "/api/actions"}:
        return _create_action(_body(event))
    if method == "GET" and path in {"/status", "/api/status"}:
        return _json_response(200, _dashboard()["system"])
    return _json_response(404, {"error": "not found", "method": method, "path": path})
