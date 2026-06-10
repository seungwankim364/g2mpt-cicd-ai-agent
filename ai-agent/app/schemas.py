from dataclasses import dataclass, field
from typing import Any


@dataclass
class CauseCandidate:
    rank: int
    title: str
    confidence: str
    evidence: list[str] = field(default_factory=list)


@dataclass
class RecommendedAction:
    type: str
    reason: str
    requiresApproval: bool = True


@dataclass
class AIRecommendation:
    deploymentId: str
    summary: str
    severity: str
    causeCandidates: list[dict[str, Any]]
    recommendedAction: dict[str, Any]
    nextSteps: list[str]
    slackMessage: dict[str, Any]

