#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


CATEGORY_PATTERNS = [
    ("cloudfront", ("cloudfront",)),
    ("eventbridge", ("eventbridge",)),
    ("dynamodb", ("dynamodb",)),
    ("elasticache", ("elasticache", "redis")),
    ("redis", ("redis", "elasticache")),
    ("lambda", ("lambda", "agent-action", "report-generator", "posture-event-processor", "thumbnail-generator", "wearable-sync", "recommendation-update", "notification", "export")),
    ("rds", ("rds", "postgres", "database")),
    ("alb", ("alb", "target-5xx", "elb-5xx", "unhealthy-host", "target-response-time")),
    ("s3", ("s3", "bucket", "object")),
    ("sqs", ("sqs", "dlq", "message-age", "visible-messages", "inflight")),
    ("waf", ("waf",)),
    ("kvs", ("kvs", "kinesisvideo", "put-media", "get-media", "incoming-bytes")),
    ("athena", ("athena",)),
    ("eks", ("eks", "node", "containerinsights")),
]


def load_json(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path: str, payload: dict) -> None:
    Path(path).write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")


def run_aws(args: list[str]) -> dict:
    completed = subprocess.run(
        ["aws", *args, "--output", "json"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or completed.stdout.strip())
    if not completed.stdout.strip():
        return {}
    return json.loads(completed.stdout)


def categorize(alarm: dict) -> str:
    name = alarm.get("AlarmName", alarm.get("alarmName", "")).lower()
    namespace = alarm.get("Namespace", alarm.get("namespace", "")).lower()
    metric = alarm.get("MetricName", alarm.get("metricName", "")).lower()
    haystack = " ".join([name, namespace, metric])
    for category, patterns in CATEGORY_PATTERNS:
        if any(pattern in haystack for pattern in patterns):
            return category
    return "unknown"


def normalize_alarm(alarm: dict, region: str) -> dict:
    return {
        "alarmName": alarm.get("AlarmName", alarm.get("alarmName")),
        "alarmArn": alarm.get("AlarmArn", alarm.get("alarmArn")),
        "region": region,
        "state": alarm.get("StateValue", alarm.get("state", "UNKNOWN")),
        "reason": alarm.get("StateReason", alarm.get("reason", "")),
        "updatedAt": str(alarm.get("StateUpdatedTimestamp", alarm.get("updatedAt", ""))),
        "category": categorize(alarm),
        "namespace": alarm.get("Namespace", alarm.get("namespace")),
        "metricName": alarm.get("MetricName", alarm.get("metricName")),
        "dimensions": alarm.get("Dimensions", alarm.get("dimensions", [])),
        "comparisonOperator": alarm.get("ComparisonOperator", alarm.get("comparisonOperator")),
        "threshold": alarm.get("Threshold", alarm.get("threshold")),
        "period": alarm.get("Period", alarm.get("period")),
        "statistic": alarm.get("Statistic", alarm.get("statistic")),
        "extendedStatistic": alarm.get("ExtendedStatistic", alarm.get("extendedStatistic")),
        "evaluationPeriods": alarm.get("EvaluationPeriods", alarm.get("evaluationPeriods")),
        "treatMissingData": alarm.get("TreatMissingData", alarm.get("treatMissingData")),
    }


def describe_region_alarms(region_config: dict) -> list[dict]:
    region = region_config["name"]
    alarms: list[dict] = []
    seen = set()
    for prefix in region_config.get("alarmNamePrefixes", []):
        response = run_aws(["cloudwatch", "describe-alarms", "--region", region, "--alarm-name-prefix", prefix])
        for alarm in response.get("MetricAlarms", []) + response.get("CompositeAlarms", []):
            key = alarm.get("AlarmArn") or f"{region}:{alarm.get('AlarmName')}"
            if key in seen:
                continue
            seen.add(key)
            alarms.append(normalize_alarm(alarm, region))
    return alarms


def metric_dimension_args(dimensions: list[dict]) -> list[str]:
    args = []
    for item in dimensions or []:
        name = item.get("Name") or item.get("name")
        value = item.get("Value") or item.get("value")
        if name and value:
            args.append(f"Name={name},Value={value}")
    return args


def collect_metric_evidence(alarms: list[dict], window_seconds: int) -> dict:
    end = datetime.now(timezone.utc).replace(microsecond=0)
    start = end - timedelta(seconds=window_seconds)
    evidence = []
    for alarm in alarms:
        namespace = alarm.get("namespace")
        metric = alarm.get("metricName")
        if not namespace or not metric:
            evidence.append({"alarmName": alarm.get("alarmName"), "region": alarm.get("region"), "status": "skipped", "reason": "metric alarm details unavailable"})
            continue

        statistic = alarm.get("statistic") or "Average"
        period = str(alarm.get("period") or 300)
        args = [
            "cloudwatch",
            "get-metric-statistics",
            "--region",
            alarm["region"],
            "--namespace",
            namespace,
            "--metric-name",
            metric,
            "--start-time",
            start.isoformat().replace("+00:00", "Z"),
            "--end-time",
            end.isoformat().replace("+00:00", "Z"),
            "--period",
            period,
            "--statistics",
            statistic,
        ]
        dimensions = metric_dimension_args(alarm.get("dimensions", []))
        if dimensions:
            args.extend(["--dimensions", *dimensions])

        try:
            response = run_aws(args)
            evidence.append(
                {
                    "alarmName": alarm.get("alarmName"),
                    "region": alarm.get("region"),
                    "namespace": namespace,
                    "metricName": metric,
                    "statistic": statistic,
                    "period": int(period),
                    "threshold": alarm.get("threshold"),
                    "comparisonOperator": alarm.get("comparisonOperator"),
                    "datapoints": sorted(response.get("Datapoints", []), key=lambda item: str(item.get("Timestamp", ""))),
                }
            )
        except Exception as error:
            evidence.append({"alarmName": alarm.get("alarmName"), "region": alarm.get("region"), "status": "unavailable", "reason": str(error)})
    return {"status": "collected", "windowSeconds": window_seconds, "datapoints": evidence}


def evaluate(config: dict, region_results: list[dict]) -> dict:
    fail_states = set(config.get("alarmStatesThatFail", ["ALARM"]))
    insufficient_fails = bool(config.get("insufficientDataIsFailure", False))
    missing_region_fails = bool(config.get("missingRegionAlarmIsFailure", True))
    failing = []
    insufficient = []
    missing_regions = []
    total = 0

    for region in region_results:
        total += region["alarmCount"]
        if region["alarmCount"] == 0:
            missing_regions.append(region["region"])
        for alarm in region["alarms"]:
            state = alarm.get("state")
            if state in fail_states:
                failing.append(alarm)
            elif state == "INSUFFICIENT_DATA":
                insufficient.append(alarm)

    failed = bool(failing) or (insufficient_fails and bool(insufficient)) or (missing_region_fails and bool(missing_regions))
    return {
        "status": "failed" if failed else "passed",
        "summary": {
            "totalAlarmCount": total,
            "failingAlarmCount": len(failing),
            "insufficientDataAlarmCount": len(insufficient),
            "missingRegionCount": len(missing_regions),
        },
        "regions": region_results,
        "failingAlarms": failing,
        "insufficientDataAlarms": insufficient,
        "missingRegions": missing_regions,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate CloudWatch alarms for the CD Quality Gate.")
    parser.add_argument("--config-file", default=os.environ.get("AWS_HEALTH_CONFIG_FILE", "config/quality-gate/aws-health-check.json"))
    parser.add_argument("--output-file", default=os.environ.get("CLOUDWATCH_OUTPUT_FILE", "cloudwatch-alarms.json"))
    parser.add_argument("--metric-output-file", default=os.environ.get("CLOUDWATCH_METRIC_OUTPUT_FILE", "cloudwatch-metrics.json"))
    parser.add_argument("--fixture-file", default=os.environ.get("CLOUDWATCH_FIXTURE_FILE", ""))
    parser.add_argument("--metric-fixture-file", default=os.environ.get("CLOUDWATCH_METRICS_FIXTURE_FILE", ""))
    parser.add_argument("--window-seconds", type=int, default=int(os.environ.get("HEALTH_CHECK_WINDOW_SECONDS", "300")))
    parser.add_argument("--required", default=os.environ.get("CLOUDWATCH_REQUIRED", "false").lower() == "true", action=argparse.BooleanOptionalAction)
    args = parser.parse_args()

    if args.fixture_file:
        payload = load_json(args.fixture_file)
        write_json(args.output_file, payload)
        if args.metric_fixture_file:
            write_json(args.metric_output_file, load_json(args.metric_fixture_file))
        else:
            write_json(args.metric_output_file, {"status": "fixture-skipped", "datapoints": []})
        return 1 if payload.get("status") == "failed" else 0

    try:
        config = load_json(args.config_file)
        region_results = []
        for region_config in config.get("regions", []):
            alarms = sorted(describe_region_alarms(region_config), key=lambda item: item.get("alarmName") or "")
            failing_count = sum(1 for alarm in alarms if alarm.get("state") in set(config.get("alarmStatesThatFail", ["ALARM"])))
            insufficient_count = sum(1 for alarm in alarms if alarm.get("state") == "INSUFFICIENT_DATA")
            region_results.append(
                {
                    "region": region_config["name"],
                    "status": "failed" if failing_count else "passed",
                    "alarmCount": len(alarms),
                    "failingAlarmCount": failing_count,
                    "insufficientDataAlarmCount": insufficient_count,
                    "alarms": alarms,
                }
            )
        payload = evaluate(config, region_results)
        evidence_alarms = payload.get("failingAlarms") or [alarm for region in region_results for alarm in region["alarms"]]
        metrics = collect_metric_evidence(evidence_alarms, args.window_seconds)
    except Exception as error:
        payload = {
            "status": "failed" if args.required else "unavailable",
            "summary": {"totalAlarmCount": 0, "failingAlarmCount": 0, "insufficientDataAlarmCount": 0, "missingRegionCount": 0},
            "regions": [],
            "failingAlarms": [],
            "insufficientDataAlarms": [],
            "missingRegions": [],
            "error": str(error),
        }
        metrics = {"status": "unavailable", "reason": str(error), "datapoints": []}

    write_json(args.output_file, payload)
    write_json(args.metric_output_file, metrics)

    if payload["status"] == "failed":
        if payload.get("error"):
            print(f"CloudWatch health check failed: {payload['error']}")
        else:
            print(f"CloudWatch health check failed: {payload['summary']['failingAlarmCount']} alarm(s), {payload['summary']['missingRegionCount']} missing region(s).")
        return 1
    if payload["status"] == "unavailable":
        print(f"CloudWatch health check unavailable: {payload.get('error', 'unknown error')}")
        return 0
    print(f"CloudWatch health check passed: {payload['summary']['totalAlarmCount']} alarm(s) evaluated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
