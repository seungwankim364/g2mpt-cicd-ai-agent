#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path


def load_json(path: str) -> dict:
    with Path(path).open("r", encoding="utf-8") as file:
        return json.load(file)


def normalize_alert(raw_alert: dict) -> dict:
    labels = raw_alert.get("labels", {})
    annotations = raw_alert.get("annotations", {})
    return {
        "alertName": labels.get("alertname") or labels.get("alertName"),
        "service": labels.get("service"),
        "namespace": labels.get("namespace"),
        "component": labels.get("component"),
        "severity": labels.get("severity", "unknown"),
        "state": raw_alert.get("state", "unknown"),
        "value": raw_alert.get("value"),
        "activeAt": raw_alert.get("activeAt") or raw_alert.get("startsAt"),
        "summary": annotations.get("summary", ""),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate Prometheus alerts for a CD quality gate.")
    parser.add_argument("--alerts-file", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--alert-names", required=True, help="Comma-separated alert names to evaluate.")
    parser.add_argument(
        "--monitored-namespaces",
        default="",
        help="Comma-separated namespaces allowed for service-adjacent infrastructure alerts.",
    )
    parser.add_argument("--output-file", default="quality-gate-result.json")
    args = parser.parse_args()

    expected_alerts = {item.strip() for item in args.alert_names.split(",") if item.strip()}
    monitored_namespaces = {args.namespace}
    monitored_namespaces.update(item.strip() for item in args.monitored_namespaces.split(",") if item.strip())
    payload = load_json(args.alerts_file)
    raw_alerts = payload.get("data", {}).get("alerts", [])
    normalized = [normalize_alert(alert) for alert in raw_alerts]

    matched = []
    for alert in normalized:
        if alert["state"] != "firing":
            continue
        if alert["alertName"] not in expected_alerts:
            continue
        if alert["service"] and alert["service"] != args.service:
            continue
        if alert["namespace"] and alert["namespace"] not in monitored_namespaces:
            continue
        matched.append(alert)

    result = {
        "service": args.service,
        "namespace": args.namespace,
        "monitoredNamespaces": sorted(monitored_namespaces),
        "evaluatedAlertNames": sorted(expected_alerts),
        "status": "failed" if matched else "passed",
        "matchedAlertCount": len(matched),
        "matchedAlerts": matched,
    }

    with Path(args.output_file).open("w", encoding="utf-8") as file:
        json.dump(result, file, indent=2)
        file.write("\n")

    if matched:
        print(f"Quality Gate failed: {len(matched)} firing alert(s) matched.")
        return 1

    print("Quality Gate passed: no matching firing alerts.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
