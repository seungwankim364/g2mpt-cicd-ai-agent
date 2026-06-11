#!/usr/bin/env python3
import argparse
import json
import urllib.request


def parse_inputs(items: list[str]) -> dict:
    result = {}
    for item in items:
        if "=" not in item:
            raise ValueError(f"Input must be key=value: {item}")
        key, value = item.split("=", 1)
        result[key] = value
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Dispatch a GitHub Actions workflow.")
    parser.add_argument("--repo", required=True, help="owner/repo")
    parser.add_argument("--workflow", required=True, help="workflow file name or id")
    parser.add_argument("--ref", default="main")
    parser.add_argument("--token", required=True)
    parser.add_argument("--input", action="append", default=[], help="workflow input as key=value")
    args = parser.parse_args()

    body = {
        "ref": args.ref,
        "inputs": parse_inputs(args.input),
    }
    request = urllib.request.Request(
        f"https://api.github.com/repos/{args.repo}/actions/workflows/{args.workflow}/dispatches",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {args.token}",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        print(f"Dispatched {args.repo}/{args.workflow}: HTTP {response.status}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
