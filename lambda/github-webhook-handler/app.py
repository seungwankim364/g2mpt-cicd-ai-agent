import base64
import hashlib
import hmac
import json
import os
import urllib.request

try:
    import boto3
except ImportError:
    boto3 = None


GITHUB_API = "https://api.github.com"
GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN", "")
GITHUB_WEBHOOK_SECRET_ARN = os.environ.get("GITHUB_WEBHOOK_SECRET_ARN", "")
EXPECTED_REPOSITORY = os.environ.get("EXPECTED_REPOSITORY", "hj-3/gympt-app")
EXPECTED_WORKFLOW_NAME = os.environ.get("EXPECTED_WORKFLOW_NAME", "Backend API CI/CD")
EXPECTED_BRANCH = os.environ.get("EXPECTED_BRANCH", "main")
QUALITY_GATE_REPO = os.environ.get("QUALITY_GATE_REPO", "seungwankim364/g2mpt-cicd-ai-agent")
QUALITY_GATE_WORKFLOW_FILE = os.environ.get("QUALITY_GATE_WORKFLOW_FILE", "quality-gate.yml")
QUALITY_GATE_REF = os.environ.get("QUALITY_GATE_REF", "main")
SERVICE_NAME = os.environ.get("SERVICE_NAME", "backend-api")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "prod")
K8S_NAMESPACE = os.environ.get("K8S_NAMESPACE", "gympt-prod")
K8S_DEPLOYMENT = os.environ.get("K8S_DEPLOYMENT", "backend-api-prod")
IMAGE_REPOSITORY = os.environ.get(
    "IMAGE_REPOSITORY",
    "337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api",
)
_SECRET_CACHE = {}


def _json_response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _body(event):
    body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        return base64.b64decode(body)
    return body.encode("utf-8")


def _headers(event):
    return {key.lower(): value for key, value in (event.get("headers") or {}).items()}


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


def _verify_signature(headers, raw_body):
    secret = _secret_value(
        GITHUB_WEBHOOK_SECRET_ARN,
        "GITHUB_WEBHOOK_SECRET",
        ("secret", "webhook_secret", "github_webhook_secret", "GITHUB_WEBHOOK_SECRET"),
    )
    if not secret:
        raise RuntimeError("GitHub webhook secret is required")
    signature = headers.get("x-hub-signature-256", "")
    if not signature.startswith("sha256="):
        return False
    digest = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(f"sha256={digest}", signature)


def _quality_gate_inputs(payload):
    run = payload["workflow_run"]
    short_sha = run.get("head_sha", "")[:7]
    image_tag = f"{run.get('run_number')}-{short_sha}"
    return {
        "service": SERVICE_NAME,
        "environment": ENVIRONMENT,
        "namespace": K8S_NAMESPACE,
        "deployment": K8S_DEPLOYMENT,
        "image_tag": f"{IMAGE_REPOSITORY}:{image_tag}",
    }


def _should_dispatch(payload):
    run = payload.get("workflow_run") or {}
    repository = payload.get("repository") or {}
    checks = {
        "action": payload.get("action") == "completed",
        "event": run.get("event") != "pull_request",
        "repository": repository.get("full_name") == EXPECTED_REPOSITORY,
        "workflow": run.get("name") == EXPECTED_WORKFLOW_NAME,
        "branch": run.get("head_branch") == EXPECTED_BRANCH,
        "conclusion": run.get("conclusion") == "success",
    }
    return all(checks.values()), checks


def _github_token():
    return _secret_value(
        GITHUB_TOKEN_SECRET_ARN,
        "GITHUB_TOKEN",
        ("token", "github_token", "GITHUB_TOKEN", "dispatch_token", "GH_WORKFLOW_DISPATCH_TOKEN"),
    )


def _dispatch_quality_gate(inputs):
    token = _github_token()
    if not token:
        raise RuntimeError("GitHub dispatch token is required")
    body = {"ref": QUALITY_GATE_REF, "inputs": inputs}
    request = urllib.request.Request(
        f"{GITHUB_API}/repos/{QUALITY_GATE_REPO}/actions/workflows/{QUALITY_GATE_WORKFLOW_FILE}/dispatches",
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
        return {"status": "dispatched", "httpStatus": response.status, "inputs": inputs}


def handler(event, context):
    headers = _headers(event)
    raw_body = _body(event)
    if headers.get("x-github-event") != "workflow_run":
        return _json_response(202, {"status": "ignored", "reason": "not workflow_run"})
    if not _verify_signature(headers, raw_body):
        return _json_response(401, {"error": "invalid github signature"})

    payload = json.loads(raw_body.decode("utf-8"))
    allowed, checks = _should_dispatch(payload)
    if not allowed:
        return _json_response(202, {"status": "ignored", "checks": checks})

    result = _dispatch_quality_gate(_quality_gate_inputs(payload))
    return _json_response(202, result)
