#!/usr/bin/env python3
import argparse
import json
import os
import urllib.request
from pathlib import Path


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
    parser = argparse.ArgumentParser(description="Send or render a CD deployment success Slack alert.")
    parser.add_argument("--service", required=True)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--image-tag", required=True)
    parser.add_argument("--output-file", default="slack-deploy-success.json")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    link_lines = []
    github_run_url = os.environ.get("GITHUB_RUN_URL")
    if github_run_url:
      link_lines.append(f"GitHub Actions: {github_run_url}")

    text = "\n".join(
        [
            f"[CD Deploy Completed] {args.service} / {args.namespace}",
            "",
            f"Image: {args.image_tag}",
            "Quality Gate: passed",
            "",
            "Links:",
            *(link_lines or ["No links provided."]),
        ]
    )
    message = {"text": text}
    slack_channel = os.environ.get("SLACK_CHANNEL")
    if slack_channel:
        message["channel"] = slack_channel

    Path(args.output_file).write_text(json.dumps(message, indent=2) + "\n", encoding="utf-8")

    webhook_url = os.environ.get("SLACK_WEBHOOK_URL")
    if args.dry_run or not webhook_url:
        print(f"Wrote Slack deployment success payload to {args.output_file}")
        return 0

    post_to_slack(webhook_url, message)
    print("Sent Slack deployment success alert")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

