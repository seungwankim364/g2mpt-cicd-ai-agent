#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
from urllib.parse import urlencode


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Grafana links for Slack and quality gate outputs.")
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--dashboard-uid", action="append", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--prometheus-url", default=os.environ.get("PROMETHEUS_URL", ""))
    parser.add_argument("--argocd-url", default=os.environ.get("ARGOCD_URL", ""))
    parser.add_argument("--argocd-app", default=os.environ.get("ARGOCD_APP", ""))
    parser.add_argument("--from-time", default="now-30m")
    parser.add_argument("--to-time", default="now")
    parser.add_argument("--output-file", default="grafana-links.json")
    args = parser.parse_args()

    query = urlencode(
        {
            "var-service": args.service,
            "var-namespace": args.namespace,
            "from": args.from_time,
            "to": args.to_time,
        }
    )
    dashboard_urls = {
        dashboard_uid: f"{args.base_url.rstrip('/')}/d/{dashboard_uid}?{query}"
        for dashboard_uid in args.dashboard_uid
    }
    links = {
        "service": args.service,
        "namespace": args.namespace,
        "grafana": {
            "dashboard": next(iter(dashboard_urls.values())),
            "dashboards": dashboard_urls,
        },
    }
    if args.prometheus_url:
        links["prometheus"] = {
            "alerts": f"{args.prometheus_url.rstrip('/')}/alerts",
        }
    if args.argocd_url:
        app_path = f"/applications/{args.argocd_app}" if args.argocd_app else ""
        links["argocd"] = f"{args.argocd_url.rstrip('/')}{app_path}"

    with Path(args.output_file).open("w", encoding="utf-8") as file:
        json.dump(links, file, indent=2)
        file.write("\n")

    print(f"Wrote Grafana links to {args.output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
