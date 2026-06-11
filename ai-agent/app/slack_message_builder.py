import json


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
    action_type = action.get("type", "observe")
    value = {
        "deploymentId": recommendation.get("deploymentId", ""),
        "service": recommendation.get("service", "backend-api"),
        "environment": recommendation.get("environment", "prod"),
        "actionType": action_type,
        "reason": action.get("reason", ""),
        "currentImageTag": recommendation.get("currentImageTag", "unknown"),
        "targetImageTag": recommendation.get("rollbackImageTag", ""),
    }
    return {
        "text": text,
        "blocks": [
            {"type": "section", "text": {"type": "mrkdwn", "text": text}},
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {"type": "plain_text", "text": f"Approve {action_type}"},
                        "style": "danger" if action_type in {"rollback", "dr"} else "primary",
                        "action_id": f"approve_{action_type}",
                        "value": json.dumps(value),
                        "confirm": {
                            "title": {"type": "plain_text", "text": f"Approve {action_type}?"},
                            "text": {"type": "mrkdwn", "text": "승인하면 자동 실행 workflow가 시작됩니다."},
                            "confirm": {"type": "plain_text", "text": "Approve"},
                            "deny": {"type": "plain_text", "text": "Cancel"},
                        },
                    }
                ],
            },
        ],
    }
