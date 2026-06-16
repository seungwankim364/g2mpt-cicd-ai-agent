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


def _recommended_action(alerts: list[dict], signals: list[dict]) -> tuple[str, str]:
    names = {_alert_name(alert) for alert in alerts}
    severities = {_alert_severity(alert) for alert in alerts}

    if "BackendHighMemoryUsage" in names:
        return "increase_memory", "Memory pressure is visible during the deploy window."
    if "BackendPodRestarting" in names or "PodRestartFrequent" in names:
        return "restart_deployment", "Pod restart or rollout instability is visible."
    if "BackendHighLatency" in names and not {"BackendHighErrorRate", "BackendDBPoolExhaustion"} & names:
        return "scale_replicas", "Latency pressure can be mitigated by more backend pods."
    if "NodeHighCPUUsage" in names:
        return "increase_hpa", "Cluster or pod CPU pressure suggests HPA headroom should be increased."
    if "BackendDBPoolExhaustion" in names:
        return "open_change_pr", "DB pool pressure needs a controlled configuration change."
    if {"RedisConnectionError", "SQSMessageAge", "SQSQueueBacklog", "SQSDLQMessages"} & names:
        return "dr", "Dependency or data-plane alerts indicate a broader failure than one pod."
    if "WAFBlockedRequestSpike" in names:
        return "open_fix_issue", "WAF behavior needs rule/config review before a safe change."
    if any(severity == "critical" for severity in severities):
        return "rollback", "Critical deployment-related alerts are firing."
    return "observe", "No automatic runbook has strong enough evidence."


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

    action_type, action_reason = _recommended_action(alerts, signals)

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
            "reason": action_reason,
            "requiresApproval": True,
        },
        "nextSteps": [
            "Open Grafana dashboard",
            "Review Athena summary",
            "Run matched runbook after operator approval",
            "Re-run Quality Gate after the approved action",
        ],
        "slackMessage": {
            "title": "Deployment failure analysis completed",
            "body": f"{summary} Recommended action: {action_type}",
            "actionButtons": [f"Approve {action_type}", "Open Grafana", "Open Argo CD"],
        },
    }
