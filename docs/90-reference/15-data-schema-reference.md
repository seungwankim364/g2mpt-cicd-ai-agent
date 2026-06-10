# DOC-28. Data Schema Reference

## 1. 목적

EventBridge event, Athena summary, AI recommendation, Slack message payload의 핵심 schema를 한 곳에서 비교할 수 있도록 정리한다.

## 2. Schema 목록

```text
schemas/eventbridge/deployment-failed.schema.json
schemas/ai-agent/athena-summary.schema.json
schemas/ai-agent/ai-recommendation.schema.json
schemas/slack/first-alert.schema.json
schemas/slack/second-alert.schema.json
schemas/rollback/rollback-request.schema.json
```

## 3. DeploymentFailed Event

```json
{
  "source": "cd.quality-gate",
  "detail-type": "DeploymentFailed",
  "time": "2026-06-09T08:20:00Z",
  "detail": {
    "deploymentId": "deploy-20260609-001",
    "service": "backend-api",
    "environment": "prod",
    "repository": "org/backend-api",
    "commitSha": "abc1234",
    "imageTag": "backend-api:abc1234",
    "argocdApp": "backend-api-prod",
    "failedAt": "2026-06-09T08:20:00Z",
    "alerts": []
  }
}
```

필수 필드:

```text
source
detail-type
detail.deploymentId
detail.service
detail.environment
detail.failedAt
detail.alerts
```

## 4. Alert Object

```json
{
  "alertName": "BackendHighErrorRate",
  "severity": "critical",
  "status": "firing",
  "value": "8.2",
  "threshold": "5",
  "startsAt": "2026-06-09T08:18:00Z",
  "labels": {
    "service": "backend-api",
    "namespace": "prod"
  },
  "annotations": {
    "summary": "Backend API error rate is high"
  }
}
```

## 5. Athena Summary

```json
{
  "deploymentId": "deploy-20260609-001",
  "service": "backend-api",
  "environment": "prod",
  "analysisWindow": {
    "start": "2026-06-09T08:10:00Z",
    "end": "2026-06-09T08:25:00Z"
  },
  "signals": [],
  "queryResults": []
}
```

## 6. Athena Signal

```json
{
  "name": "alb_5xx_spike",
  "severity": "critical",
  "summary": "ALB target 5xx increased on /api/v1/orders",
  "evidence": {
    "count": 320,
    "topPath": "/api/v1/orders",
    "targetStatusCode": "500"
  }
}
```

## 7. AI Recommendation

```json
{
  "deploymentId": "deploy-20260609-001",
  "summary": "Backend API deployment failed after error rate increased.",
  "severity": "critical",
  "causeCandidates": [],
  "recommendedAction": {
    "type": "rollback",
    "reason": "Failure started immediately after deployment.",
    "requiresApproval": true
  },
  "nextSteps": [],
  "slackMessage": {}
}
```

허용 action:

```text
rollback
manual_fix
dr
observe
```

## 8. Cause Candidate

```json
{
  "rank": 1,
  "title": "Application error on order API",
  "confidence": "high",
  "evidence": [
    "BackendHighErrorRate alert firing",
    "ALB 5xx concentrated on /api/v1/orders"
  ]
}
```

허용 confidence:

```text
high
medium
low
```

## 9. Slack First Alert

```json
{
  "type": "first_alert",
  "deploymentId": "deploy-20260609-001",
  "service": "backend-api",
  "environment": "prod",
  "summary": "Deployment failed by Quality Gate",
  "alerts": [],
  "links": {
    "githubActions": "...",
    "grafana": "...",
    "argocd": "..."
  }
}
```

## 10. Slack Second Alert

```json
{
  "type": "second_alert",
  "deploymentId": "deploy-20260609-001",
  "summary": "AI analysis completed",
  "causeCandidates": [],
  "recommendedAction": {
    "type": "rollback",
    "requiresApproval": true
  },
  "links": {
    "athenaSummary": "s3://...",
    "grafana": "...",
    "argocd": "..."
  },
  "actions": [
    {
      "id": "approve_rollback",
      "label": "Approve Rollback"
    }
  ]
}
```

## 11. Rollback Request

```json
{
  "deploymentId": "deploy-20260609-001",
  "service": "backend-api",
  "environment": "prod",
  "currentImageTag": "backend-api:abc1234",
  "rollbackImageTag": "backend-api:def5678",
  "approvedBy": "ops-user",
  "approvedAt": "2026-06-09T08:35:00Z",
  "reason": "Quality Gate failure after deployment"
}
```

## 12. 공통 검증 규칙

```text
timestamp는 ISO-8601 UTC
deploymentId는 모든 payload에서 동일
environment는 dev/staging/prod 중 하나
recommendedAction.requiresApproval은 true
Slack payload에는 민감 정보 포함 금지
```

