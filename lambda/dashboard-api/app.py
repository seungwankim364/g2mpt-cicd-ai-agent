import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from decimal import Decimal

try:
    import boto3
except ImportError:
    boto3 = None


EVENT_BUS_NAME = os.environ.get("EVENT_BUS_NAME", "")
ACTION_TABLE_NAME = os.environ.get("ACTION_TABLE_NAME", "")
RESULT_BUCKET = os.environ.get("RESULT_BUCKET", "")
GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN", "")
GITHUB_REPOSITORY = os.environ.get("GITHUB_REPOSITORY", "hj-3/gympt-app")
GITHUB_WORKFLOW_FILE = os.environ.get("GITHUB_WORKFLOW_FILE", "backend-api-ci.yml")
GITHUB_BRANCH = os.environ.get("GITHUB_BRANCH", "main")
ARGOCD_URL = os.environ.get("ARGOCD_URL", "https://argocd.g2mpt.com").rstrip("/")
ARGOCD_APP = os.environ.get("ARGOCD_APP", "backend-api-prod")
ARGOCD_TOKEN_SECRET_ARN = os.environ.get("ARGOCD_TOKEN_SECRET_ARN", "")
PROMETHEUS_URL = os.environ.get("PROMETHEUS_URL", "http://kube-prometheus-stack-prometheus.monitoring.svc:9090").rstrip("/")
HTTP_TIMEOUT_SECONDS = float(os.environ.get("DASHBOARD_HTTP_TIMEOUT_SECONDS", "4"))
_SECRET_CACHE = {}
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


def _parse_secret(secret, candidate_keys):
    if not secret:
        return ""
    try:
        parsed = json.loads(secret)
    except json.JSONDecodeError:
        return secret
    if isinstance(parsed, dict):
        for key in candidate_keys:
            if parsed.get(key):
                return parsed[key]
        if len(parsed) == 1:
            return next(iter(parsed.values()))
    return secret


def _secret_value(secret_arn, env_name, candidate_keys):
    if os.environ.get(env_name):
        return os.environ[env_name]
    if secret_arn in _SECRET_CACHE:
        return _SECRET_CACHE[secret_arn]
    if not secret_arn or boto3 is None:
        return ""
    response = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
    value = _parse_secret(response.get("SecretString", ""), candidate_keys)
    _SECRET_CACHE[secret_arn] = value
    return value


def _http_json(url, headers=None):
    request = urllib.request.Request(url, headers=headers or {}, method="GET")
    with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
        return json.loads(response.read().decode("utf-8"))


def _unavailable(source, reason):
    return {"status": "unavailable", "source": source, "reason": str(reason)}


def _github_token():
    return _secret_value(
        GITHUB_TOKEN_SECRET_ARN,
        "GITHUB_TOKEN",
        ("token", "github_token", "GITHUB_TOKEN", "dispatch_token", "GH_WORKFLOW_DISPATCH_TOKEN"),
    )


def _github_workflow_status():
    workflow = urllib.parse.quote(GITHUB_WORKFLOW_FILE, safe="")
    query = urllib.parse.urlencode({"branch": GITHUB_BRANCH, "per_page": 5})
    url = f"https://api.github.com/repos/{GITHUB_REPOSITORY}/actions/workflows/{workflow}/runs?{query}"
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "cd-quality-gate-dashboard",
    }
    try:
        token = _github_token()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        payload = _http_json(url, headers)
        runs = payload.get("workflow_runs", [])
        latest = runs[0] if runs else {}
        conclusion = latest.get("conclusion")
        status = latest.get("status", "unknown")
        dashboard_status = "complete" if conclusion == "success" else "failed" if conclusion else "waiting"
        return {
            "status": dashboard_status,
            "source": "github",
            "repository": GITHUB_REPOSITORY,
            "workflow": GITHUB_WORKFLOW_FILE,
            "branch": GITHUB_BRANCH,
            "latest": {
                "id": latest.get("id"),
                "runNumber": latest.get("run_number"),
                "status": status,
                "conclusion": conclusion or "",
                "event": latest.get("event", ""),
                "headBranch": latest.get("head_branch", ""),
                "headSha": latest.get("head_sha", ""),
                "createdAt": latest.get("created_at", ""),
                "updatedAt": latest.get("updated_at", ""),
                "url": latest.get("html_url", f"https://github.com/{GITHUB_REPOSITORY}/actions/workflows/{GITHUB_WORKFLOW_FILE}"),
            },
            "runs": [
                {
                    "runNumber": run.get("run_number"),
                    "status": run.get("status", ""),
                    "conclusion": run.get("conclusion") or "",
                    "headSha": run.get("head_sha", "")[:7],
                    "updatedAt": run.get("updated_at", ""),
                    "url": run.get("html_url", ""),
                }
                for run in runs[:5]
            ],
        }
    except Exception as exc:
        return _unavailable("github", exc)


def _argocd_token():
    return _secret_value(ARGOCD_TOKEN_SECRET_ARN, "ARGOCD_TOKEN", ("token", "argocd_token", "ARGOCD_TOKEN"))


def _argocd_status():
    url = f"{ARGOCD_URL}/api/v1/applications/{urllib.parse.quote(ARGOCD_APP, safe='')}"
    headers = {"Accept": "application/json"}
    try:
        token = _argocd_token()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        payload = _http_json(url, headers)
        status = payload.get("status", {})
        sync = status.get("sync", {})
        health = status.get("health", {})
        operation = status.get("operationState", {})
        sync_status = sync.get("status", "Unknown")
        health_status = health.get("status", "Unknown")
        dashboard_status = "complete" if sync_status == "Synced" and health_status == "Healthy" else "warning"
        return {
            "status": dashboard_status,
            "source": "argocd",
            "app": ARGOCD_APP,
            "syncStatus": sync_status,
            "healthStatus": health_status,
            "revision": sync.get("revision", ""),
            "operationPhase": operation.get("phase", ""),
            "message": health.get("message", ""),
            "url": f"{ARGOCD_URL}/applications/{ARGOCD_APP}",
        }
    except Exception as exc:
        return _unavailable("argocd", exc)


def _prometheus_status():
    url = f"{PROMETHEUS_URL}/api/v1/alerts"
    try:
        payload = _http_json(url, {"Accept": "application/json"})
        alerts = payload.get("data", {}).get("alerts", [])
        firing = [alert for alert in alerts if alert.get("state") == "firing"]
        return {
            "status": "failed" if firing else "complete",
            "source": "prometheus",
            "url": PROMETHEUS_URL,
            "totalAlerts": len(alerts),
            "firingAlerts": len(firing),
            "alerts": [
                {
                    "name": alert.get("labels", {}).get("alertname", "unknown"),
                    "severity": alert.get("labels", {}).get("severity", "unknown"),
                    "namespace": alert.get("labels", {}).get("namespace", ""),
                    "summary": alert.get("annotations", {}).get("summary", ""),
                    "description": alert.get("annotations", {}).get("description", ""),
                    "activeAt": alert.get("activeAt", ""),
                }
                for alert in firing[:20]
            ],
        }
    except Exception as exc:
        return _unavailable("prometheus", exc)


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
        "live": {
            "github": {"status": "waiting", "source": "github"},
            "argocd": {"status": "waiting", "source": "argocd"},
            "prometheus": {"status": "waiting", "source": "prometheus"},
        },
        "links": {
            "grafana": "https://grafana.g2mpt.com",
            "prometheus": PROMETHEUS_URL,
            "argocd": f"{ARGOCD_URL}/applications/{ARGOCD_APP}",
            "githubRun": f"https://github.com/{GITHUB_REPOSITORY}/actions/workflows/{GITHUB_WORKFLOW_FILE}",
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


def _apply_live_integrations(dashboard):
    github = _github_workflow_status()
    argocd = _argocd_status()
    prometheus = _prometheus_status()
    dashboard["live"] = {"github": github, "argocd": argocd, "prometheus": prometheus}

    latest = github.get("latest") or {}
    if latest.get("headSha"):
        dashboard["deployment"]["commitSha"] = latest["headSha"]
    if latest.get("runNumber") and latest.get("headSha"):
        dashboard["deployment"]["imageTag"] = f"backend-api:{latest['runNumber']}-{latest['headSha'][:7]}"
    if latest.get("updatedAt"):
        dashboard["deployment"]["lastUpdatedAt"] = latest["updatedAt"]

    if prometheus.get("status") == "failed":
        dashboard["deployment"]["status"] = "failed"
        dashboard["healthWindow"]["result"] = "failed"
    elif github.get("status") == "complete" and argocd.get("status") == "complete" and prometheus.get("status") == "complete":
        dashboard["deployment"]["status"] = "complete"
        dashboard["healthWindow"]["result"] = "complete"
    elif any(item.get("status") == "unavailable" for item in (github, argocd, prometheus)):
        dashboard["deployment"]["status"] = "warning"
        dashboard["healthWindow"]["result"] = "waiting"
    else:
        dashboard["deployment"]["status"] = "waiting"

    timeline_status = {
        "push": github.get("status", "waiting"),
        "gitops": "complete" if github.get("status") == "complete" else "waiting",
        "argocd": argocd.get("status", "waiting"),
        "gate": prometheus.get("status", "waiting"),
    }
    timeline_detail = {
        "push": f"{GITHUB_WORKFLOW_FILE}: {latest.get('status', 'unknown')} / {latest.get('conclusion') or '-'}",
        "gitops": "GitOps values update is inferred from successful backend workflow.",
        "argocd": f"sync={argocd.get('syncStatus', '-')}, health={argocd.get('healthStatus', '-')}",
        "gate": f"{prometheus.get('firingAlerts', 0)} firing alert(s) from Prometheus.",
    }
    dashboard["timeline"] = [
        {
            **item,
            "status": timeline_status.get(item["id"], item["status"]),
            "detail": timeline_detail.get(item["id"], item["detail"]),
            "at": format_live_time(latest.get("updatedAt", "")) if item["id"] == "push" else item["at"],
        }
        for item in dashboard["timeline"]
    ]

    if prometheus.get("alerts"):
        dashboard["alertGroups"] = [
            {
                "name": "Prometheus firing alerts",
                "severity": "critical",
                "count": prometheus.get("firingAlerts", 0),
                "dashboards": ["prometheus", "grafana"],
                "alerts": [
                    {
                        "name": alert.get("name", "unknown"),
                        "severity": alert.get("severity", "unknown"),
                        "summary": alert.get("summary") or alert.get("description", ""),
                        "value": alert.get("namespace", ""),
                    }
                    for alert in prometheus["alerts"]
                ],
            }
        ]
    elif prometheus.get("status") == "complete":
        dashboard["alertGroups"] = [
            {
                "name": "Prometheus firing alerts",
                "severity": "available",
                "count": 0,
                "dashboards": ["prometheus", "grafana"],
                "alerts": [],
            }
        ]
    return dashboard


def format_live_time(value):
    return value or "-"


def _dashboard():
    actions = _list_actions()
    dashboard = _apply_live_integrations(_apply_latest_analysis(_base_dashboard()))
    dashboard["system"] = {
        "backend": {"status": "connected", "api": "dashboard-api-lambda"},
        "database": {"status": "connected", "type": "dynamodb", "records": len(actions)},
        "eventBridge": {"status": "connected" if EVENT_BUS_NAME else "unavailable", "bus": EVENT_BUS_NAME},
        "resultBucket": {"status": "connected" if RESULT_BUCKET else "unavailable", "bucket": RESULT_BUCKET},
        "prometheus": {"status": dashboard["live"]["prometheus"]["status"], "url": dashboard["links"]["prometheus"]},
        "grafana": {"status": "linked", "url": dashboard["links"]["grafana"]},
        "argocd": {"status": dashboard["live"]["argocd"]["status"], "url": dashboard["links"]["argocd"]},
        "githubActions": {"status": dashboard["live"]["github"]["status"], "url": dashboard["links"]["githubRun"]},
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
