import importlib
import sys
from pathlib import Path


def _load_ai_agent():
    try:
        analyzer = importlib.import_module("ai_agent.analyzer")
        slack_builder = importlib.import_module("ai_agent.slack_message_builder")
        return analyzer.analyze, slack_builder.build_second_alert
    except ImportError:
        repo_ai_agent = Path(__file__).resolve().parents[2] / "ai-agent" / "app"
        if repo_ai_agent.exists():
            sys.path.insert(0, str(repo_ai_agent))
            analyzer = importlib.import_module("analyzer")
            slack_builder = importlib.import_module("slack_message_builder")
            return analyzer.analyze, slack_builder.build_second_alert
        raise


def analyze_locally(summary):
    analyze, build_second_alert = _load_ai_agent()
    recommendation = analyze(summary)
    recommendation["slackPayload"] = build_second_alert(
        recommendation,
        links={
            "grafana": summary.get("grafanaLinks", {}),
            "argocd": summary.get("argocdUrl", "n/a"),
        },
    )
    return recommendation
