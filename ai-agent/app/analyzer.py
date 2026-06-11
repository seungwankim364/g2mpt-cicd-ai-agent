try:
    from .runbook_loader import load_runbooks
except ImportError:
    from runbook_loader import load_runbooks


def _alert_name(alert: dict) -> str:
    return alert.get("alertName") or alert.get("labels", {}).get("alertname", "UnknownAlert")


def _alert_severity(alert: dict) -> str:
    return alert.get("severity") or alert.get("labels", {}).get("severity", "unknown")


def _summary(alert: dict) -> str:
    return alert.get("summary") or alert.get("annotations", {}).get("summary", "")


def analyze(payload: dict) -> dict:
    deployment = payload.get("deployment") or payload
    alerts = payload.get("prometheus", {}).get("alerts") or payload.get("alerts", [])
    signals = payload.get("athena", {}).get("signals") or payload.get("signals", [])
    runbooks = load_runbooks(alerts)

    candidates = []
    for index, alert in enumerate(alerts[:3], start=1):
        name = _alert_name(alert)
        evidence = [_summary(alert)] if _summary(alert) else [name]
        for signal in signals[:2]:
            if signal.get("summary"):
                evidence.append(signal["summary"])
        candidates.append(
            {
                "rank": index,
                "title": f"{name} after deployment",
                "confidence": "high" if _alert_severity(alert) == "critical" and signals else "medium",
                "evidence": evidence,
                "runbook": runbooks[index - 1]["path"] if index - 1 < len(runbooks) else None,
            }
        )

    action_type = "rollback" if any(_alert_severity(alert) == "critical" for alert in alerts) else "observe"
    if any(_alert_name(alert) == "WAFBlockedRequestSpike" for alert in alerts):
        action_type = "manual_fix"

    service = deployment.get("service", "unknown-service")
    deployment_id = deployment.get("deploymentId", payload.get("deploymentId", "unknown-deployment"))
    summary = f"{service} deployment failure analyzed with {len(alerts)} alert(s)."
    return {
        "deploymentId": deployment_id,
        "service": service,
        "environment": deployment.get("environment", payload.get("environment", "prod")),
        "currentImageTag": deployment.get("imageTag", payload.get("imageTag", "unknown")),
        "rollbackImageTag": deployment.get("rollbackImageTag", payload.get("rollbackImageTag", "")),
        "summary": summary,
        "severity": "critical" if action_type == "rollback" else "warning",
        "causeCandidates": candidates,
        "recommendedAction": {
            "type": action_type,
            "reason": "Critical deployment-related alerts are firing." if action_type == "rollback" else "Manual review is safer based on available evidence.",
            "requiresApproval": True,
        },
        "nextSteps": [
            "Open Grafana dashboard",
            "Review Athena summary",
            "Run matched runbook",
            "Approve rollback only after operator review",
        ],
        "slackMessage": {
            "title": "Deployment failure analysis completed",
            "body": f"{summary} Recommended action: {action_type}",
            "actionButtons": ["Approve rollback", "Open Grafana", "Open Argo CD"],
        },
    }
