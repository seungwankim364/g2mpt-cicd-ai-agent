import json
import os
import re

try:
    import boto3
except ImportError:
    boto3 = None

try:
    from ai_agent.slack_message_builder import build_second_alert
except ImportError:
    from slack_message_builder import build_second_alert


BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
BEDROCK_REGION = os.environ.get("BEDROCK_REGION", os.environ.get("AWS_REGION", "ap-northeast-2"))
BEDROCK_MAX_TOKENS = int(os.environ.get("BEDROCK_MAX_TOKENS", "1200"))

ALLOWED_ACTIONS = {
    "rollback",
    "restart_deployment",
    "scale_replicas",
    "increase_memory",
    "increase_hpa",
    "open_fix_issue",
    "open_change_pr",
    "observe",
}


def _compact_summary(summary: dict) -> dict:
    return {
        "deploymentId": summary.get("deploymentId"),
        "service": summary.get("service"),
        "environment": summary.get("environment"),
        "imageTag": summary.get("imageTag"),
        "rollbackImageTag": summary.get("rollbackImageTag"),
        "failedAt": summary.get("failedAt"),
        "analysisWindow": summary.get("analysisWindow"),
        "alerts": summary.get("alerts", [])[:10],
        "signals": summary.get("signals", [])[:10],
        "queryResults": summary.get("queryResults", [])[:10],
        "grafanaLinks": summary.get("grafanaLinks", {}),
        "prometheusLinks": summary.get("prometheusLinks", {}),
        "argocdUrl": summary.get("argocdUrl", ""),
    }


def _prompt(summary: dict) -> str:
    compact = _compact_summary(summary)
    return "\n".join(
        [
            "Analyze this CD Quality Gate deployment failure.",
            "Use only the provided evidence. Do not invent logs, metrics, or root causes.",
            "Choose exactly one recommendedAction.type from: rollback, restart_deployment, scale_replicas, increase_memory, increase_hpa, open_fix_issue, open_change_pr, observe.",
            "Use rollback only when the evidence points to the new deployment as the likely cause.",
            "Use open_fix_issue when infrastructure or dependency failure is broader than one deploy and needs operator review.",
            "Use restart_deployment for pod restart or stuck rollout symptoms when the image is not clearly bad.",
            "Use scale_replicas for traffic/latency pressure that can be mitigated by more pods.",
            "Use increase_memory for OOM, heap, memory pressure, or memory-limit symptoms.",
            "Use increase_hpa for sustained CPU/load pressure when HPA maxReplicas is the likely limiter.",
            "Use open_fix_issue when code or configuration must be changed by a developer.",
            "Use open_change_pr when a controlled GitOps/Terraform change is needed but the exact value requires review.",
            "Always set recommendedAction.requiresApproval to true.",
            "Return JSON only. Do not wrap the JSON in markdown.",
            "",
            "Required JSON shape:",
            json.dumps(
                {
                    "deploymentId": "string",
                    "service": "string",
                    "environment": "string",
                    "currentImageTag": "string",
                    "rollbackImageTag": "string",
                    "summary": "string",
                    "severity": "critical|warning|info",
                    "causeCandidates": [
                        {
                            "rank": 1,
                            "title": "string",
                            "confidence": "high|medium|low",
                            "evidence": ["string"],
                        }
                    ],
                    "recommendedAction": {
                        "type": "rollback|restart_deployment|scale_replicas|increase_memory|increase_hpa|open_fix_issue|open_change_pr|observe",
                        "reason": "string",
                        "requiresApproval": True,
                    },
                    "nextSteps": ["string"],
                    "slackMessage": {
                        "title": "string",
                        "body": "string",
                        "actionButtons": ["string"],
                    },
                },
                indent=2,
            ),
            "",
            "Evidence JSON:",
            json.dumps(compact, ensure_ascii=False, indent=2),
        ]
    )


def _extract_text(response: dict) -> str:
    content = response.get("content", [])
    if content and isinstance(content, list):
        first = content[0]
        if isinstance(first, dict):
            return first.get("text", "")
    return response.get("completion", "")


def _parse_json(text: str) -> dict:
    stripped = text.strip()
    if stripped.startswith("```"):
        match = re.search(r"```(?:json)?\s*(.*?)```", stripped, flags=re.DOTALL)
        if match:
            stripped = match.group(1).strip()
    return json.loads(stripped)


def _normalize_recommendation(recommendation: dict, summary: dict) -> dict:
    action = recommendation.setdefault("recommendedAction", {})
    action_type = action.get("type", "observe")
    if action_type not in ALLOWED_ACTIONS:
        action_type = "observe"
    action["type"] = action_type
    action["requiresApproval"] = True
    action.setdefault("reason", "Bedrock analysis completed with limited evidence.")

    recommendation["deploymentId"] = recommendation.get("deploymentId") or summary.get("deploymentId", "")
    recommendation["service"] = recommendation.get("service") or summary.get("service", "backend-api")
    recommendation["environment"] = recommendation.get("environment") or summary.get("environment", "prod")
    recommendation["currentImageTag"] = recommendation.get("currentImageTag") or summary.get("imageTag", "unknown")
    recommendation["rollbackImageTag"] = recommendation.get("rollbackImageTag") or summary.get("rollbackImageTag", "")
    recommendation.setdefault("summary", "Bedrock incident analysis completed.")
    recommendation.setdefault("severity", "warning")
    recommendation.setdefault("causeCandidates", [])
    recommendation.setdefault("nextSteps", ["Open Grafana dashboard", "Review Athena summary", "Check matching runbook"])
    recommendation.setdefault(
        "slackMessage",
        {
            "title": "Deployment failure analysis completed",
            "body": recommendation["summary"],
            "actionButtons": [f"Approve {action_type}", "Open Grafana", "Open Argo CD"],
        },
    )
    return recommendation


def analyze_with_bedrock(summary: dict) -> dict:
    if boto3 is None:
        raise RuntimeError("boto3 is required for Bedrock analysis")

    client = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)
    request = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": BEDROCK_MAX_TOKENS,
        "temperature": 0.2,
        "system": "You are a cautious CD incident analysis assistant. Return valid JSON only.",
        "messages": [{"role": "user", "content": [{"type": "text", "text": _prompt(summary)}]}],
    }
    response = client.invoke_model(
        modelId=BEDROCK_MODEL_ID,
        body=json.dumps(request).encode("utf-8"),
        contentType="application/json",
        accept="application/json",
    )
    response_body = json.loads(response["body"].read().decode("utf-8"))
    recommendation = _normalize_recommendation(_parse_json(_extract_text(response_body)), summary)
    recommendation["analysisEngine"] = "bedrock"
    recommendation["bedrockModelId"] = BEDROCK_MODEL_ID
    recommendation["slackPayload"] = build_second_alert(
        recommendation,
        links={
            "grafana": summary.get("grafanaLinks", {}),
            "argocd": summary.get("argocdUrl", "n/a"),
        },
    )
    return recommendation
