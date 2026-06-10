def build_second_alert(recommendation: dict, links: dict | None = None) -> dict:
    links = links or {}
    candidates = recommendation.get("causeCandidates", [])
    candidate_lines = [
        f"- #{item.get('rank')}: {item.get('title')} ({item.get('confidence')})"
        for item in candidates
    ] or ["- No strong cause candidate found."]
    action = recommendation.get("recommendedAction", {})
    text = "\n".join(
        [
            f"[AI Analysis] {recommendation.get('summary', '')}",
            "",
            "Cause candidates:",
            *candidate_lines,
            "",
            f"Recommended action: {action.get('type')} - {action.get('reason')}",
            f"Requires approval: {action.get('requiresApproval', True)}",
            "",
            f"Grafana: {links.get('grafana', {}).get('dashboard', 'n/a')}",
            f"Argo CD: {links.get('argocd', 'n/a')}",
        ]
    )
    return {"text": text}

