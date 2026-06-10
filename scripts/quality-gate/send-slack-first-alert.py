#!/usr/bin/env python3
import argparse
import json
import os
import urllib.request
from pathlib import Path


def load_json(path: str) -> dict:
    with Path(path).open("r", encoding="utf-8") as file:
        return json.load(file)


def build_message(result: dict, links: dict, github_run_url: str | None) -> dict:
    service = result["service"]
    namespace = result["namespace"]
    alerts = result.get("matchedAlerts", [])
    alert_lines = []
    for alert in alerts:
        alert_lines.append(
            f"- {alert['alertName']} ({alert['severity']}): {alert.get('summary') or 'No summary'}"
        )
    if not alert_lines:
        alert_lines.append("- No matching alert details found.")

    link_lines = []
    grafana_url = links.get("grafana", {}).get("dashboard")
    if grafana_url:
        link_lines.append(f"Grafana: {grafana_url}")
    if github_run_url:
        link_lines.append(f"GitHub Actions: {github_run_url}")

    text = "\n".join(
        [
            f"[CD Quality Gate Failed] {service} / {namespace}",
            "",
            "Matched alerts:",
            *alert_lines,
            "",
            "Links:",
            *(link_lines or ["No links provided."]),
        ]
    )
    message = {"text": text}
    slack_channel = os.environ.get("SLACK_CHANNEL")
    if slack_channel:
        message["channel"] = slack_channel
    return message


def post_to_slack(webhook_url: str, message: dict) -> None:
    body = json.dumps(message).encode("utf-8")
    request = urllib.request.Request(
        webhook_url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        if response.status >= 300:
            raise RuntimeError(f"Slack webhook failed with HTTP {response.status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Send or render the first Slack alert.")
    parser.add_argument("--result-file", required=True)
    parser.add_argument("--links-file", required=True)
    parser.add_argument("--output-file", default="slack-first-alert.json")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    result = load_json(args.result_file)
    links = load_json(args.links_file)
    github_run_url = os.environ.get("GITHUB_RUN_URL")
    message = build_message(result, links, github_run_url)

    with Path(args.output_file).open("w", encoding="utf-8") as file:
        json.dump(message, file, indent=2)
        file.write("\n")

    webhook_url = os.environ.get("SLACK_WEBHOOK_URL")
    if args.dry_run or not webhook_url:
        print(f"Wrote Slack message payload to {args.output_file}")
        return 0

    post_to_slack(webhook_url, message)
    print("Sent Slack first alert")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
