#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

try:
    from .analyzer import analyze
    from .slack_message_builder import build_second_alert
except ImportError:
    from analyzer import analyze
    from slack_message_builder import build_second_alert


def main() -> int:
    parser = argparse.ArgumentParser(description="Run local AI incident analysis.")
    parser.add_argument("--input-file", required=True)
    parser.add_argument("--output-file", default="ai-recommendation.json")
    parser.add_argument("--slack-output-file", default="slack-second-alert.json")
    args = parser.parse_args()

    payload = json.loads(Path(args.input_file).read_text(encoding="utf-8"))
    recommendation = analyze(payload)
    Path(args.output_file).write_text(json.dumps(recommendation, indent=2) + "\n", encoding="utf-8")
    Path(args.slack_output_file).write_text(json.dumps(build_second_alert(recommendation), indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.output_file} and {args.slack_output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
