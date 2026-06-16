import json
import os
import urllib.request

try:
    import boto3
except ImportError:
    boto3 = None


GITHUB_API = "https://api.github.com"
GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN", "")
APP_DEPLOY_WORKFLOW_REPO = os.environ.get("APP_DEPLOY_WORKFLOW_REPO", "")
APP_DEPLOY_WORKFLOW_FILE = os.environ.get("APP_DEPLOY_WORKFLOW_FILE", "backend-api-ci.yml")
APP_DEPLOY_WORKFLOW_REF = os.environ.get("APP_DEPLOY_WORKFLOW_REF", "main")

WORKFLOW_REPOS = {
    "rollback": os.environ.get("ROLLBACK_WORKFLOW_REPO", ""),
    "manual_fix": os.environ.get("MANUAL_FIX_WORKFLOW_REPO", ""),
    "change": os.environ.get("CHANGE_WORKFLOW_REPO", ""),
    "restart_deployment": os.environ.get("CHANGE_WORKFLOW_REPO", ""),
    "scale_replicas": os.environ.get("CHANGE_WORKFLOW_REPO", ""),
    "increase_memory": os.environ.get("CHANGE_WORKFLOW_REPO", ""),
    "increase_hpa": os.environ.get("CHANGE_WORKFLOW_REPO", ""),
    "open_fix_issue": os.environ.get("MANUAL_FIX_WORKFLOW_REPO", ""),
    "open_change_pr": os.environ.get("CHANGE_WORKFLOW_REPO", ""),
}

WORKFLOW_FILES = {
    "rollback": os.environ.get("ROLLBACK_WORKFLOW_FILE", "rollback.yml"),
    "manual_fix": os.environ.get("MANUAL_FIX_WORKFLOW_FILE", "manual-fix.yml"),
    "change": os.environ.get("CHANGE_WORKFLOW_FILE", "change-apply.yml"),
    "restart_deployment": os.environ.get("CHANGE_WORKFLOW_FILE", "change-apply.yml"),
    "scale_replicas": os.environ.get("CHANGE_WORKFLOW_FILE", "change-apply.yml"),
    "increase_memory": os.environ.get("CHANGE_WORKFLOW_FILE", "change-apply.yml"),
    "increase_hpa": os.environ.get("CHANGE_WORKFLOW_FILE", "change-apply.yml"),
    "open_fix_issue": os.environ.get("MANUAL_FIX_WORKFLOW_FILE", "manual-fix.yml"),
    "open_change_pr": os.environ.get("CHANGE_WORKFLOW_FILE", "change-apply.yml"),
}


def _secret_value(secret_arn):
    if not secret_arn or boto3 is None:
        return os.environ.get("GITHUB_TOKEN", "")
    response = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
    secret = response.get("SecretString", "")
    if not secret:
        return ""
    try:
        parsed = json.loads(secret)
    except json.JSONDecodeError:
        return secret
    if isinstance(parsed, dict):
        for key in ("token", "github_token", "GITHUB_TOKEN", "dispatch_token", "GH_WORKFLOW_DISPATCH_TOKEN"):
            if parsed.get(key):
                return parsed[key]
        if len(parsed) == 1:
            return next(iter(parsed.values()))
    return secret


def _dispatch_workflow(repo, workflow_file, token, detail):
    if not repo:
        raise ValueError(f"No workflow repository configured for action {detail['actionType']}")
    target_image_tag = detail.get("targetImageTag") or detail.get("currentImageTag", "")
    body = {
        "ref": os.environ.get("WORKFLOW_REF", "main"),
        "inputs": {
            "deployment_id": detail["deploymentId"],
            "service": detail["service"],
            "environment": detail["environment"],
            "action_type": detail["actionType"],
            "approved_by": detail["approvedBy"],
            "reason": detail.get("reason", ""),
            "current_image_tag": detail.get("currentImageTag", "unknown"),
            "target_image_tag": target_image_tag,
            "app_repo": APP_DEPLOY_WORKFLOW_REPO,
            "app_workflow": APP_DEPLOY_WORKFLOW_FILE,
            "app_ref": APP_DEPLOY_WORKFLOW_REF,
        },
    }
    request = urllib.request.Request(
        f"{GITHUB_API}/repos/{repo}/actions/workflows/{workflow_file}/dispatches",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return {"status": "dispatched", "httpStatus": response.status}


def handler(event, context):
    detail = event.get("detail", event)
    action_type = detail["actionType"]
    token = _secret_value(GITHUB_TOKEN_SECRET_ARN)
    if not token:
        raise RuntimeError("GitHub token is required to dispatch approved action workflows")
    result = _dispatch_workflow(
        WORKFLOW_REPOS.get(action_type, ""),
        WORKFLOW_FILES.get(action_type, ""),
        token,
        detail,
    )
    return {"statusCode": 200, "body": result}
