# DOC-08. Events and Slack Messages

## 1. EventBridge 이벤트

### 이벤트 목적

배포 실패 이벤트를 GitHub Actions에서 분석 파이프라인으로 비동기 전달한다.

### 이벤트 예시

```json
{
  "source": "gympt.cicd",
  "detail-type": "DeploymentFailed",
  "detail": {
    "service": "backend-api",
    "environment": "prod",
    "imageTag": "abc1234",
    "commitSha": "abc1234",
    "argocdApp": "backend-api-prod",
    "failedAt": "2026-06-08T15:20:00+09:00",
    "alerts": [
      "BackendHighErrorRate",
      "BackendHighLatency"
    ],
    "grafanaUrl": "https://grafana.gympt.com/d/backend",
    "prometheusUrl": "https://prometheus.gympt.com/alerts",
    "argocdUrl": "https://argocd.gympt.com/applications/backend-api-prod"
  }
}
```

## 2. 1차 Slack 알림: 배포 실패 감지

```text
[Deployment Quality Gate Failed] backend-api / prod

배포 직후 서비스 상태 검증에 실패했습니다.

Service: backend-api
Environment: prod
Image: backend-api:abc1234
Commit: abc1234
Argo CD App: backend-api-prod
Detected At: 2026-06-08 15:20 KST

Detected Alerts:
- BackendHighErrorRate
- BackendHighLatency
- BackendPodRestarting

Metrics:
- 5xx Error Rate: 8.4%
- p95 Latency: 2.8s
- Pod Restart: 3

Links:
- Grafana Backend Dashboard
- Prometheus Alerts
- Argo CD Application
- GitHub Actions Run

Next:
EventBridge DeploymentFailed 이벤트를 발행했고,
Athena + AI 분석 파이프라인을 시작했습니다.
```

현재 1차 Slack 알림 payload는 아래 링크를 포함한다.

```text
Grafana dashboard URL
Prometheus alerts URL
Argo CD application URL
GitHub Actions run URL
```

주의:

```text
Prometheus URL이 EKS 내부 service 주소이면 Slack에서 클릭한 사용자가 직접 열 수 없을 수 있다.
이 경우 Grafana 링크를 1차 확인 링크로 사용하고, Prometheus 링크는 self-hosted runner 또는 cluster 내부 확인용으로 본다.
```

## 3. 2차 Slack 알림: AI 분석 결과

```text
[AI Incident Analysis Result] backend-api / prod

배포 실패 원인 분석이 완료되었습니다.

Summary:
배포 직후 /api/workouts/recommendation API에서 500 에러가 급증했습니다.
Athena 로그 분석 결과 DB connection timeout 로그가 반복적으로 확인되었습니다.

Evidence:
- 5xx Error Rate: 8.4%
- p95 Latency: 2.8s
- 주요 에러: DB connection timeout
- 영향 API: /api/workouts/recommendation
- 영향 서비스: backend-api, recommendation-update

AI Recommendation:
Rollback 권장

Reason:
장애가 새 이미지 배포 직후 발생했고,
특정 API에서 동일한 timeout 패턴이 반복되고 있습니다.
이전 버전에서는 동일 alert가 발생하지 않았으므로 우선 rollback 후 원인 수정이 안전합니다.

Recommended Actions:
1. Argo CD Rollback 승인
2. DB Connection Pool 설정 확인
3. 최근 migration 변경 확인
4. AgentService 호출부 timeout 설정 확인

Links:
- Grafana Backend Dashboard
- Prometheus Alert
- Argo CD Application
- Athena Result S3
- Runbook
```

## 4. Athena Query 예시

## 5. 승인 이벤트: rollback / DR / manual fix / change

AI Agent가 추천한 조치를 운영자가 승인하면 승인 이벤트를 EventBridge에 발행한다.

이 이벤트는 승인 audit trail이면서 자동 실행 trigger다. EventBridge rule이 `deployment-action-executor` Lambda를 호출하고, Lambda가 action type에 맞는 GitHub Actions workflow를 dispatch한다.

```json
{
  "source": "cd.quality-gate",
  "detail-type": "DeploymentActionApproved",
  "detail": {
    "deploymentId": "backend-api-prod-2026-06-11T06:00:00Z",
    "service": "backend-api",
    "environment": "prod",
    "actionType": "rollback",
    "approvedBy": "seungwankim364",
    "approvedAt": "2026-06-11T06:05:00Z",
    "reason": "BackendHighErrorRate and DB pool exhaustion after deployment",
    "currentImageTag": "backend-api:abc1234",
    "targetImageTag": "backend-api:def5678",
    "status": "approved"
  }
}
```

현재 실행 경로:

```text
Slack 2차 알림 승인 버튼
  -> API Gateway /slack/interactions
  -> lambda/slack-approval-handler/app.py
  -> EventBridge DeploymentActionApproved
  -> lambda/deployment-action-executor/app.py
  -> rollback / dr / manual_fix / change workflow dispatch
  -> 필요 시 gympt-app 배포 workflow dispatch
```

수동 fallback 경로:

```text
GitHub Actions approved-action.yml workflow_dispatch
  -> scripts/quality-gate/publish-approved-action-event.sh
  -> EventBridge cd-quality-gate-prod-bus
  -> lambda/deployment-action-executor/app.py
```

주의:

```text
rollback 자동 실행에는 targetImageTag가 필요하다.
DeploymentFailed 이벤트에 rollbackImageTag가 없으면 Slack 승인 payload의 targetImageTag가 비어 rollback workflow가 실패할 수 있다.
따라서 기존 app 배포 workflow가 이전 정상 image tag를 ROLLBACK_IMAGE_TAG로 넘기거나, 별도 배포 이력 저장소에서 조회해야 한다.
```

```sql
SELECT
  request_uri,
  status,
  COUNT(*) AS error_count
FROM alb_access_logs
WHERE status >= 500
  AND timestamp BETWEEN TIMESTAMP '2026-06-08 15:10:00'
                    AND TIMESTAMP '2026-06-08 15:25:00'
GROUP BY request_uri, status
ORDER BY error_count DESC
LIMIT 20;
```

## 5. 분석 결과 S3 경로 예시

```text
deployment-failures/
  service=backend-api/
  date=2026-06-08/
  commit=abc1234/
    prometheus-alerts.json
    athena-summary.json
    ai-recommendation.json
```
