def analyze_locally(summary):
    alerts = summary.get("alerts", [])
    candidates = []
    for index, alert in enumerate(alerts[:3], start=1):
        name = alert.get("alertName") or alert.get("labels", {}).get("alertname", "UnknownAlert")
        candidates.append(
            {
                "rank": index,
                "title": f"{name} after deployment",
                "confidence": "medium",
                "evidence": [alert.get("summary") or str(alert)],
            }
        )
    action = "rollback" if candidates else "observe"
    return {
        "deploymentId": summary["deploymentId"],
        "summary": f"{summary['service']} deployment analysis completed.",
        "severity": "critical" if candidates else "info",
        "causeCandidates": candidates,
        "recommendedAction": {
            "type": action,
            "reason": "Prometheus alert evidence was found." if candidates else "No strong evidence found.",
            "requiresApproval": True,
        },
        "nextSteps": ["Review Grafana dashboard", "Review Athena summary", "Follow matched runbook"],
        "slackMessage": {
            "title": "Deployment failure analysis completed",
            "body": f"{summary['service']} analysis completed. Recommended action: {action}",
        },
    }

