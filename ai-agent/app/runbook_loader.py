from pathlib import Path


RUNBOOK_MAPPING = {
    "BackendHighErrorRate": "backend-high-error-rate.sh",
    "BackendHighLatency": "backend-high-latency.sh",
    "BackendPodRestarting": "pod-restarting.sh",
    "DBConnectionError": "db-connection-error.sh",
    "WAFBlockedRequestSpike": "waf-blocked-request-spike.sh",
}


def find_runbook(alert_name: str, base_dir: str = "scripts/runbooks") -> dict:
    filename = RUNBOOK_MAPPING.get(alert_name)
    if not filename:
        return {"alertName": alert_name, "path": None, "content": ""}
    path = Path(base_dir) / filename
    content = path.read_text(encoding="utf-8") if path.exists() else ""
    return {"alertName": alert_name, "path": str(path), "content": content}


def load_runbooks(alerts: list[dict]) -> list[dict]:
    loaded = []
    for alert in alerts:
        alert_name = alert.get("alertName") or alert.get("labels", {}).get("alertname")
        if alert_name:
            loaded.append(find_runbook(alert_name))
    return loaded

