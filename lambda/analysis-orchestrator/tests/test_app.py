import json
from pathlib import Path

import app


def test_handler_with_sample_event(monkeypatch, tmp_path):
    monkeypatch.setattr(app, "LOCAL_RESULT_DIR", str(tmp_path))
    sample = json.loads(Path("lambda/analysis-orchestrator/events/deployment-failed.sample.json").read_text())
    result = app.handler(sample, None)
    assert result["statusCode"] == 200
    assert result["body"]["aiResult"]["recommendedAction"]["requiresApproval"] is True

