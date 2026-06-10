# DOC-20. AI Agent Prompt and Output Design

## 1. 목적

AI Agent가 배포 실패 원인 후보와 대응 방안을 일관된 형식으로 생성하도록 입력, prompt, 출력 schema를 정의한다.

AI Agent는 운영자를 대신해 자동 조치를 실행하지 않는다. 분석 결과와 추천 조치를 제공하고, 최종 실행은 운영자 승인 이후 별도 workflow에서 수행한다.

## 2. Agent 역할

```text
Prometheus alert 해석
Athena summary 해석
Runbook 매칭
원인 후보 정리
추천 조치 선택
Slack 2차 알림용 메시지 생성
```

## 3. 입력 데이터

AI Agent 입력은 하나의 JSON payload로 전달한다.

```json
{
  "deployment": {
    "deploymentId": "deploy-20260609-001",
    "service": "backend-api",
    "environment": "prod",
    "commitSha": "abc1234",
    "imageTag": "backend-api:abc1234",
    "failedAt": "2026-06-09T08:20:00Z"
  },
  "prometheus": {
    "alerts": []
  },
  "athena": {
    "summaryS3Path": "s3://cd-quality-gate-results/...",
    "signals": []
  },
  "links": {
    "grafana": [],
    "argocd": "https://argocd.example.com/applications/backend-api-prod"
  },
  "runbooks": []
}
```

## 4. Prompt 구성

Prompt는 다음 블록으로 구성한다.

```text
System instruction
Task instruction
Deployment context
Prometheus alert summary
Athena evidence summary
Runbook guidance
Output schema instruction
Safety constraints
```

## 5. System Instruction

```text
You are an incident analysis assistant for a CD quality gate.
Analyze deployment failure signals and produce evidence-based recommendations.
Do not invent facts that are not present in the provided evidence.
Do not recommend destructive actions without explicit operator approval.
```

## 6. Task Instruction

```text
1. Summarize what changed in this deployment.
2. Identify the most likely failure cause candidates.
3. Link each candidate to concrete evidence.
4. Recommend one of rollback, manual_fix, dr, or observe.
5. Explain why the recommendation is appropriate.
6. Generate a concise Slack message for operators.
```

## 7. Runbook Matching

Alert 이름을 기준으로 Runbook을 우선 매칭한다.

| Alert | Runbook |
| --- | --- |
| BackendHighErrorRate | `backend-high-error-rate.sh` |
| BackendHighLatency | `backend-high-latency.sh` |
| BackendPodRestarting | `pod-restarting.sh` |
| DBConnectionError | `db-connection-error.sh` |
| WAFBlockedRequestSpike | `waf-blocked-request-spike.sh` |

여러 alert가 동시에 발생하면 severity가 높은 alert의 runbook을 우선 적용하고, 나머지는 보조 evidence로 사용한다.

## 8. 출력 Schema

AI Agent 출력은 JSON이어야 한다.

```json
{
  "deploymentId": "deploy-20260609-001",
  "summary": "Backend API deployment failed after error rate increased.",
  "severity": "critical",
  "causeCandidates": [
    {
      "rank": 1,
      "title": "Application error on order API",
      "confidence": "high",
      "evidence": [
        "BackendHighErrorRate alert firing",
        "ALB 5xx concentrated on /api/v1/orders",
        "application-error-patterns found NullPointerException"
      ]
    }
  ],
  "recommendedAction": {
    "type": "rollback",
    "reason": "Failure started immediately after deployment and affects critical API path.",
    "requiresApproval": true
  },
  "nextSteps": [
    "Review Grafana backend dashboard",
    "Approve rollback if impact continues",
    "Check application logs for the top exception pattern"
  ],
  "slackMessage": {
    "title": "Deployment failure analysis completed",
    "body": "Backend API shows increased 5xx after deployment.",
    "actionButtons": ["Approve rollback", "Open Grafana", "Open Argo CD"]
  }
}
```

## 9. Recommendation Type

| Type | 의미 |
| --- | --- |
| rollback | 새 배포가 장애 원인일 가능성이 높아 이전 버전 복구 권장 |
| manual_fix | 설정, DB, 외부 의존성 등 수동 조치가 우선 |
| dr | 리전/인프라 장애 가능성이 있어 DR 절차 검토 |
| observe | 영향이 작거나 근거가 부족해 모니터링 지속 |

## 10. Confidence 기준

| Confidence | 기준 |
| --- | --- |
| high | Prometheus alert, Athena evidence, 배포 시점이 모두 일치 |
| medium | alert와 로그 evidence는 있으나 배포 변경과 직접 연결은 약함 |
| low | 신호가 부족하거나 외부 요인 가능성이 큼 |

## 11. Slack 메시지 원칙

Slack 메시지는 운영자가 빠르게 판단할 수 있어야 한다.

포함 정보:

```text
서비스명
환경
배포 ID
장애 요약
원인 후보 1~3개
추천 조치
근거 링크
승인 버튼
```

포함하지 않을 정보:

```text
민감한 로그 원문
토큰 또는 header 값
장황한 query 결과 전체
확정되지 않은 단정 표현
```

## 12. Guardrails

```text
제공된 evidence에 없는 원인 생성 금지
자동 rollback 실행 금지
보안 정보 노출 금지
confidence가 낮으면 rollback보다 observe 또는 manual_fix 권장
AI 판단과 근거를 분리해서 출력
```

## 13. 검증 기준

```text
정상 sample payload에서 schema에 맞는 JSON 출력
Athena evidence가 비어 있어도 graceful fallback 가능
Runbook 매칭 실패 시 기본 분석 prompt 사용
Slack message가 1분 내 읽을 수 있는 길이로 생성
recommendedAction.requiresApproval이 항상 true로 설정
```

