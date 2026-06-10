def build_prompt(payload: dict, runbooks: list[dict]) -> str:
    deployment = payload.get("deployment") or payload
    alerts = payload.get("prometheus", {}).get("alerts") or payload.get("alerts", [])
    athena = payload.get("athena", {}) or payload
    runbook_text = "\n\n".join(
        f"Runbook: {item.get('alertName')}\nPath: {item.get('path')}\n{item.get('content', '')[:2000]}"
        for item in runbooks
    )
    return "\n".join(
        [
            "Analyze this CD Quality Gate failure using only the evidence below.",
            "",
            f"Deployment: {deployment}",
            f"Prometheus alerts: {alerts}",
            f"Athena evidence: {athena}",
            "",
            "Matched runbooks:",
            runbook_text or "No runbook matched.",
            "",
            "Return JSON with summary, causeCandidates, recommendedAction, nextSteps, slackMessage.",
        ]
    )

