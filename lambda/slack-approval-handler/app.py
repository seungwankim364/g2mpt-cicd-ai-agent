import base64
import hashlib
import hmac
import json
import os
import time
import urllib.parse
from datetime import datetime, timezone

try:
    import boto3
except ImportError:
    boto3 = None


EVENT_BUS_NAME = os.environ.get("EVENT_BUS_NAME", "cd-quality-gate-prod-bus")
SLACK_SIGNING_SECRET = os.environ.get("SLACK_SIGNING_SECRET", "")
SLACK_SIGNING_SECRET_ARN = os.environ.get("SLACK_SIGNING_SECRET_ARN", "")
_SLACK_SIGNING_SECRET_CACHE = None


def _body(event):
    body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        return base64.b64decode(body).decode("utf-8")
    return body


def _headers(event):
    return {key.lower(): value for key, value in (event.get("headers") or {}).items()}


def _verify_slack_signature(event, body):
    signing_secret = _slack_signing_secret()
    if not signing_secret:
        return True
    headers = _headers(event)
    timestamp = headers.get("x-slack-request-timestamp", "")
    signature = headers.get("x-slack-signature", "")
    if not timestamp or not signature:
        return False
    if abs(time.time() - int(timestamp)) > 60 * 5:
        return False
    base = f"v0:{timestamp}:{body}".encode("utf-8")
    digest = hmac.new(signing_secret.encode("utf-8"), base, hashlib.sha256).hexdigest()
    return hmac.compare_digest(f"v0={digest}", signature)


def _slack_signing_secret():
    global _SLACK_SIGNING_SECRET_CACHE
    if SLACK_SIGNING_SECRET:
        return SLACK_SIGNING_SECRET
    if _SLACK_SIGNING_SECRET_CACHE is not None:
        return _SLACK_SIGNING_SECRET_CACHE
    if boto3 is None or not SLACK_SIGNING_SECRET_ARN:
        return ""
    response = boto3.client("secretsmanager").get_secret_value(SecretId=SLACK_SIGNING_SECRET_ARN)
    _SLACK_SIGNING_SECRET_CACHE = response.get("SecretString", "")
    return _SLACK_SIGNING_SECRET_CACHE


def _parse_payload(body):
    parsed = urllib.parse.parse_qs(body)
    payload = parsed.get("payload", ["{}"])[0]
    return json.loads(payload)


def _approval_detail(payload):
    action = payload.get("actions", [{}])[0]
    value = json.loads(action.get("value", "{}"))
    user = payload.get("user", {})
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    return {
        "deploymentId": value["deploymentId"],
        "service": value["service"],
        "environment": value["environment"],
        "actionType": value["actionType"],
        "approvedBy": user.get("username") or user.get("name") or user.get("id", "unknown"),
        "approvedAt": now,
        "reason": value.get("reason", ""),
        "currentImageTag": value.get("currentImageTag", "unknown"),
        "targetImageTag": value.get("targetImageTag", ""),
        "status": "approved",
    }


def _put_event(detail):
    if boto3 is None:
        return {"status": "dry-run", "detail": detail}
    events = boto3.client("events")
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


def handler(event, context):
    body = _body(event)
    if not _verify_slack_signature(event, body):
        return {"statusCode": 401, "body": "invalid slack signature"}
    payload = _parse_payload(body)
    detail = _approval_detail(payload)
    _put_event(detail)
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"text": f"Approved {detail['actionType']} for {detail['service']}."}),
    }
