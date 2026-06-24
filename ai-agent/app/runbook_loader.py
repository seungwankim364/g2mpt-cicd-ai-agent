from pathlib import Path


RUNBOOK_MAPPING = {
    "BackendHighErrorRate": "backend-high-error-rate.sh",
    "BackendHighLatency": "backend-high-latency.sh",
    "BackendPodRestarting": "pod-restarting.sh",
    "BackendDBPoolExhaustion": "backend-db-pool-exhaustion.sh",
    "BackendHighMemoryUsage": "backend-high-memory-usage.sh",
    "WAFBlockedRequestSpike": "waf-blocked-request-spike.sh",
}

PATTERN_RUNBOOKS = [
    (("rds", "cpu"), "rds-high-cpu.sh"),
    (("rds", "connection"), "rds-connection-high.sh"),
    (("rds", "storage"), "rds-free-storage-low.sh"),
    (("rds", "memory"), "rds-free-memory-low.sh"),
    (("rds", "latency"), "rds-latency-high.sh"),
    (("rds", "deadlock"), "rds-deadlocks.sh"),
    (("lambda", "error"), "lambda-errors-high.sh"),
    (("lambda", "duration"), "lambda-duration-high.sh"),
    (("lambda", "throttle"), "lambda-throttles-high.sh"),
    (("lambda", "concurrency"), "lambda-concurrency-high.sh"),
    (("lambda", "event-age"), "lambda-async-event-age-high.sh"),
    (("lambda", "dlq"), "lambda-dlq-errors.sh"),
    (("alb", "5xx"), "alb-5xx-high.sh"),
    (("alb", "response-time"), "alb-target-response-time-high.sh"),
    (("alb", "unhealthy"), "alb-unhealthy-host-high.sh"),
    (("alb", "rejected"), "alb-rejected-connections.sh"),
    (("alb", "tls"), "alb-tls-errors.sh"),
    (("s3", "4xx"), "s3-4xx-high.sh"),
    (("s3", "5xx"), "s3-5xx-high.sh"),
    (("s3", "latency"), "s3-first-byte-latency-high.sh"),
    (("s3", "request"), "s3-request-spike.sh"),
    (("s3", "bucket-size"), "s3-bucket-size-high.sh"),
    (("cloudfront", "5xx"), "cloudfront-5xx-high.sh"),
    (("cloudfront", "4xx"), "cloudfront-4xx-high.sh"),
    (("cloudfront", "origin-latency"), "cloudfront-origin-latency-high.sh"),
    (("cloudfront", "request"), "cloudfront-request-spike.sh"),
    (("kvs", "put-media"), "kvs-put-media-errors.sh"),
    (("kvs", "get-media"), "kvs-get-media-errors.sh"),
    (("kvs", "incoming-bytes"), "kvs-incoming-bytes-low.sh"),
    (("eventbridge", "failed"), "eventbridge-failed-invocations.sh"),
    (("eventbridge", "throttled"), "eventbridge-throttled-rules.sh"),
    (("eventbridge", "dlq"), "eventbridge-dlq-invocations.sh"),
    (("athena", "failure"), "athena-query-failures.sh"),
    (("athena", "processed-bytes"), "athena-processed-bytes-high.sh"),
    (("dynamodb", "system-errors"), "dynamodb-system-errors.sh"),
    (("dynamodb", "user-errors"), "dynamodb-user-errors.sh"),
    (("dynamodb", "read-throttles"), "dynamodb-read-throttles.sh"),
    (("dynamodb", "write-throttles"), "dynamodb-write-throttles.sh"),
    (("dynamodb", "transaction-conflicts"), "dynamodb-transaction-conflicts.sh"),
    (("dynamodb", "consumed-read"), "dynamodb-consumed-read-spike.sh"),
    (("dynamodb", "consumed-write"), "dynamodb-consumed-write-spike.sh"),
]


def pattern_filename(alert_name: str) -> str | None:
    normalized = alert_name.lower().replace("_", "-")
    for patterns, filename in PATTERN_RUNBOOKS:
        if all(pattern in normalized for pattern in patterns):
            return filename
    return None


def find_runbook(alert_name: str, base_dir: str = "scripts/runbooks") -> dict:
    filename = RUNBOOK_MAPPING.get(alert_name) or pattern_filename(alert_name)
    if not filename:
        return {"alertName": alert_name, "path": None, "content": ""}
    path = Path(base_dir) / filename
    content = path.read_text(encoding="utf-8") if path.exists() else ""
    return {"alertName": alert_name, "path": str(path), "content": content}


def load_runbooks(alerts: list[dict]) -> list[dict]:
    loaded = []
    for alert in alerts:
        alert_name = alert.get("alertName") or alert.get("name") or alert.get("labels", {}).get("alertname")
        if alert_name:
            loaded.append(find_runbook(alert_name))
    return loaded
