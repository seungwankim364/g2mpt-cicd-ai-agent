from app.slack_message_builder import build_second_alert


def test_build_second_alert_text():
    message = build_second_alert(
        {
            "summary": "analysis done",
            "causeCandidates": [{"rank": 1, "title": "error", "confidence": "high"}],
            "recommendedAction": {"type": "rollback", "reason": "critical", "requiresApproval": True},
        }
    )
    assert "rollback" in message["text"]

