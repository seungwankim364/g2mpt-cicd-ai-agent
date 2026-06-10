from app.analyzer import analyze


def test_analyze_recommends_approval_required():
    result = analyze(
        {
            "deploymentId": "deploy-1",
            "service": "backend-api",
            "alerts": [{"alertName": "BackendHighErrorRate", "severity": "critical", "summary": "5xx high"}],
            "signals": [{"summary": "ALB 5xx increased"}],
        }
    )
    assert result["recommendedAction"]["requiresApproval"] is True
    assert result["recommendedAction"]["type"] == "rollback"

