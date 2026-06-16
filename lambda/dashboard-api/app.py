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


def _dashboard():
    actions = _list_actions()
    return {
        "mode": "aws-dashboard",
        "generatedAt": int(time.time()),
        "system": {
            "backend": {"status": "connected", "api": "dashboard-api-lambda"},
            "database": {"status": "connected", "type": "dynamodb", "records": len(actions)},
            "eventBridge": {"status": "connected" if EVENT_BUS_NAME else "unavailable", "bus": EVENT_BUS_NAME},
            "resultBucket": {"status": "connected" if RESULT_BUCKET else "unavailable", "bucket": RESULT_BUCKET},
        },
        "actionHistory": actions,
    }


def _create_action(payload):
    now = int(time.time())
    action_type = payload.get("actionType") or payload.get("action")
    if not action_type:
        return _json_response(400, {"error": "actionType is required"})

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
