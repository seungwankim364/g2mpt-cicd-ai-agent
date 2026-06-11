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
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")
LOCAL_RESULT_DIR = os.environ.get("LOCAL_RESULT_DIR", "/tmp/cd-quality-gate-results")


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

    template = json.loads(template_path.read_text(encoding="utf-8"))
    athena = boto3.client("athena")
    for item in template.get("queries", []):
        query_file = item["file"] if isinstance(item, dict) else item
        sql_path = Path("athena/queries") / query_file
        if not sql_path.exists():
            continue
        response = athena.start_query_execution(
            QueryString=sql_path.read_text(encoding="utf-8"),
            QueryExecutionContext={"Database": ATHENA_DATABASE},
            ResultConfiguration={"OutputLocation": ATHENA_OUTPUT_LOCATION},
            WorkGroup=ATHENA_WORKGROUP,
        )
        query_ids.append({"id": query_file.replace(".sql", ""), "queryExecutionId": response["QueryExecutionId"]})
    return query_ids


def wait_or_collect_query_results(query_ids):
    if boto3 is None:
        return []
    athena = boto3.client("athena")
    results = []
    for item in query_ids:
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
    return {
        "deploymentId": detail["deploymentId"],
        "service": detail["service"],
        "environment": detail["environment"],
        "failedAt": detail["failedAt"],
        "analysisWindow": build_analysis_window(detail["failedAt"]),
        "alerts": detail.get("alerts", []),
        "signals": [
            {
                "name": alert.get("alertName") or alert.get("labels", {}).get("alertname", "unknown"),
                "severity": alert.get("severity") or alert.get("labels", {}).get("severity", "unknown"),
                "summary": alert.get("summary") or alert.get("annotations", {}).get("summary", ""),
                "evidence": alert,
            }
            for alert in detail.get("alerts", [])
        ],
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
    if not AI_AGENT_ENDPOINT:
        from ai_agent_adapter import analyze_locally

        return analyze_locally(summary)
    request = urllib.request.Request(
        AI_AGENT_ENDPOINT,
        data=json.dumps(summary).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def send_second_slack_alert(result):
    if not SLACK_WEBHOOK_URL:
        return {"status": "skipped", "reason": "SLACK_WEBHOOK_URL not set"}
    message = result.get("slackPayload") or {
        "text": result.get("slackMessage", {}).get("body") or result.get("summary", "AI analysis completed")
    }
    request = urllib.request.Request(
        SLACK_WEBHOOK_URL,
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
