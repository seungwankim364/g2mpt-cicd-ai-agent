import json
import os
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:
    import boto3
except ImportError:  # Allows local unit tests without boto3.
    boto3 = None


RESULT_BUCKET = os.environ.get("RESULT_BUCKET", "")
ATHENA_DATABASE = os.environ.get("ATHENA_DATABASE", "cd_quality_gate_logs")
ATHENA_WORKGROUP = os.environ.get("ATHENA_WORKGROUP", "cd-quality-gate")
ATHENA_OUTPUT_LOCATION = os.environ.get("ATHENA_OUTPUT_LOCATION", "")
AI_AGENT_ENDPOINT = os.environ.get("AI_AGENT_ENDPOINT", "")
BEDROCK_ENABLED = os.environ.get("BEDROCK_ENABLED", "false").lower() == "true"
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")
SLACK_WEBHOOK_SECRET_ARN = os.environ.get("SLACK_WEBHOOK_SECRET_ARN", "")
LOCAL_RESULT_DIR = os.environ.get("LOCAL_RESULT_DIR", "/tmp/cd-quality-gate-results")
_SLACK_WEBHOOK_CACHE = None


def parse_deployment_failed_event(event):
    detail = event.get("detail", event)
    required = ["deploymentId", "service", "environment", "failedAt"]
    missing = [name for name in required if not detail.get(name)]
    if missing:
        raise ValueError(f"Missing required event detail fields: {', '.join(missing)}")
    return detail


def build_analysis_window(failed_at):
    failed = datetime.fromisoformat(failed_at.replace("Z", "+00:00"))
    return {
        "start": (failed - timedelta(minutes=10)).astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "end": (failed + timedelta(minutes=5)).astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
    }


def start_athena_queries(detail):
    template_path = Path("athena/templates") / f"{detail['service']}.json"
    query_ids = []
    if not template_path.exists() or boto3 is None or not ATHENA_OUTPUT_LOCATION:
        return query_ids

    window = build_analysis_window(detail["failedAt"])
    template = json.loads(template_path.read_text(encoding="utf-8"))
    athena = boto3.client("athena")
    for item in template.get("queries", []):
        query_file = item["file"] if isinstance(item, dict) else item
        sql_path = Path("athena/queries") / query_file
        if not sql_path.exists():
            continue
        query_id = query_file.replace(".sql", "")
        sql = (
            sql_path.read_text(encoding="utf-8")
            .replace(":start_time", f"'{window['start']}'")
            .replace(":end_time", f"'{window['end']}'")
        )
        try:
            response = athena.start_query_execution(
                QueryString=sql,
                QueryExecutionContext={"Database": ATHENA_DATABASE},
                ResultConfiguration={"OutputLocation": ATHENA_OUTPUT_LOCATION},
                WorkGroup=ATHENA_WORKGROUP,
            )
            query_ids.append({"id": query_id, "queryExecutionId": response["QueryExecutionId"]})
        except Exception as error:
            query_ids.append({"id": query_id, "status": "FAILED_TO_START", "error": str(error)})
    return query_ids


def wait_or_collect_query_results(query_ids):
    if boto3 is None:
        return []
    athena = boto3.client("athena")
    results = []
    for item in query_ids:
        if item.get("status") == "FAILED_TO_START":
            results.append(item)
            continue
        query_id = item["queryExecutionId"]
        state = "RUNNING"
        for _ in range(12):
            execution = athena.get_query_execution(QueryExecutionId=query_id)
            state = execution["QueryExecution"]["Status"]["State"]
            if state in {"SUCCEEDED", "FAILED", "CANCELLED"}:
                break
            time.sleep(5)
        results.append({"id": item["id"], "queryExecutionId": query_id, "status": state})
    return results


def build_summary(detail, query_results):
    cloudwatch_signals = [
        {
            "name": alarm.get("alarmName", "unknown"),
            "severity": "critical" if alarm.get("state") == "ALARM" else "warning",
            "summary": "{category} CloudWatch alarm is {state}: {reason}".format(
                category=alarm.get("category", "unknown"),
                state=alarm.get("state", "unknown"),
                reason=alarm.get("reason") or alarm.get("metricName") or "No reason",
            ),
            "evidence": alarm,
        }
        for alarm in detail.get("cloudwatchAlarms", [])
    ]
    return {
        "deploymentId": detail["deploymentId"],
        "service": detail["service"],
        "environment": detail["environment"],
        "imageTag": detail.get("imageTag", "unknown"),
        "rollbackImageTag": detail.get("rollbackImageTag", ""),
        "failedAt": detail["failedAt"],
        "analysisWindow": build_analysis_window(detail["failedAt"]),
        "alerts": detail.get("alerts", []),
        "cloudwatchAlarms": detail.get("cloudwatchAlarms", []),
        "cloudwatchInsufficientDataAlarms": detail.get("cloudwatchInsufficientDataAlarms", []),
        "awsHealth": detail.get("awsHealth", {}),
        "awsMetricEvidence": detail.get("awsMetricEvidence", {}),
        "grafanaLinks": detail.get("grafanaLinks", {}),
        "prometheusLinks": detail.get("prometheusLinks", {}),
        "argocdUrl": detail.get("argocdUrl", ""),
        "signals": [
            {
                "name": alert.get("alertName") or alert.get("labels", {}).get("alertname", "unknown"),
                "severity": alert.get("severity") or alert.get("labels", {}).get("severity", "unknown"),
                "summary": alert.get("summary") or alert.get("annotations", {}).get("summary", ""),
                "evidence": alert,
            }
            for alert in detail.get("alerts", [])
        ]
        + cloudwatch_signals,
        "queryResults": query_results,
    }


def write_summary_to_s3(summary):
    key = "deployment-failures/{environment}/{service}/{deploymentId}/athena-summary.json".format(**summary)
    body = json.dumps(summary, indent=2)
    if boto3 is not None and RESULT_BUCKET:
        boto3.client("s3").put_object(Bucket=RESULT_BUCKET, Key=key, Body=body.encode("utf-8"))
        return f"s3://{RESULT_BUCKET}/{key}"

    path = Path(LOCAL_RESULT_DIR) / key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body + "\n", encoding="utf-8")
    return str(path)


def invoke_ai_agent(summary):
    if AI_AGENT_ENDPOINT:
        request = urllib.request.Request(
            AI_AGENT_ENDPOINT,
            data=json.dumps(summary).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))

    if BEDROCK_ENABLED:
        try:
            from bedrock_agent import analyze_with_bedrock

            return analyze_with_bedrock(summary)
        except Exception as error:
            print(f"Bedrock analysis failed. Falling back to local ai-agent: {error}")

    from ai_agent_adapter import analyze_locally

    return analyze_locally(summary)


def slack_webhook_url():
    global _SLACK_WEBHOOK_CACHE
    if SLACK_WEBHOOK_URL:
        return SLACK_WEBHOOK_URL
    if _SLACK_WEBHOOK_CACHE is not None:
        return _SLACK_WEBHOOK_CACHE
    if boto3 is None or not SLACK_WEBHOOK_SECRET_ARN:
        return ""
    response = boto3.client("secretsmanager").get_secret_value(SecretId=SLACK_WEBHOOK_SECRET_ARN)
    _SLACK_WEBHOOK_CACHE = _parse_secret_value(
        response.get("SecretString", ""),
        ("url", "webhook_url", "slack_webhook_url", "SLACK_WEBHOOK_URL"),
    )
    return _SLACK_WEBHOOK_CACHE


def _parse_secret_value(secret, candidate_keys):
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


def send_second_slack_alert(result):
    webhook_url = slack_webhook_url()
    if not webhook_url:
        return {"status": "skipped", "reason": "SLACK_WEBHOOK_URL not set"}
    message = result.get("slackPayload") or {
        "text": result.get("slackMessage", {}).get("body") or result.get("summary", "AI analysis completed")
    }
    request = urllib.request.Request(
        webhook_url,
        data=json.dumps(message).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return {"status": "sent", "httpStatus": response.status}


def handler(event, context):
    detail = parse_deployment_failed_event(event)
    query_ids = start_athena_queries(detail)
    query_results = wait_or_collect_query_results(query_ids)
    summary = build_summary(detail, query_results)
    summary_path = write_summary_to_s3(summary)
    ai_result = invoke_ai_agent(summary)
    slack_result = send_second_slack_alert(ai_result)
    return {
        "statusCode": 200,
        "body": {
            "summaryPath": summary_path,
            "aiResult": ai_result,
            "slack": slack_result,
        },
    }


if __name__ == "__main__":
    sample = json.loads(Path("lambda/analysis-orchestrator/events/deployment-failed.sample.json").read_text())
    print(json.dumps(handler(sample, None), indent=2))
