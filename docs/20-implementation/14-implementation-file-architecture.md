# DOC-14. Implementation File Architecture

## 1. 목적

이 문서는 실제 구현 단계에서 사용할 폴더 구조와 파일 역할을 정의한다.

현재 문서 저장소가 아니라, 실제로 `CD Quality Gate + EventBridge + Athena + AI Agent + Slack` 시스템을 만들 때 필요한 repository 구조를 기준으로 작성한다.

## 2. 추천 Repository 구조

```text
cd-quality-gate/
  README.md
  .github/
    workflows/
      cd.yml
      quality-gate.yml
  scripts/
    cd/
      update-gitops-image-tag.sh
      wait-argocd-app.sh
      check-k8s-rollout.sh
    quality-gate/
      query-prometheus-alerts.sh
      query-prometheus-metrics.sh
      evaluate-quality-gate.py
      build-grafana-links.py
      send-slack-first-alert.py
      publish-eventbridge-event.sh
    runbooks/
      backend-high-error-rate.sh
      backend-high-latency.sh
      pod-restarting.sh
      db-connection-error.sh
      waf-blocked-request-spike.sh
  lambda/
    analysis-orchestrator/
      app.py
      requirements.txt
      template.yaml
      events/
        deployment-failed.sample.json
      tests/
        test_app.py
  ai-agent/
    app/
      main.py
      analyzer.py
      prompt_builder.py
      runbook_loader.py
      slack_message_builder.py
      schemas.py
    prompts/
      incident-analysis-system.md
      incident-analysis-user-template.md
    tests/
      test_analyzer.py
      test_slack_message_builder.py
    requirements.txt
  athena/
    queries/
      alb-5xx-errors.sql
      api-latency-top-paths.sql
      waf-blocked-requests.sql
      cloudfront-5xx-errors.sql
      application-error-patterns.sql
    templates/
      backend-api.json
      posture-analysis-service.json
      worker-lambda.json
    schemas/
      alb_access_logs.sql
      cloudfront_access_logs.sql
      waf_logs.sql
      application_logs.sql
  infra/
    terraform/
      main.tf
      variables.tf
      outputs.tf
      eventbridge.tf
      lambda.tf
      iam.tf
      s3.tf
      athena.tf
      slack.tf
    sam/
      template.yaml
  config/
    services/
      backend-api.yaml
      posture-analysis-service.yaml
      worker-lambda.yaml
    environments/
      dev.yaml
      prod.yaml
    quality-gate/
      thresholds.yaml
      alert-mapping.yaml
      grafana-dashboards.yaml
  schemas/
    eventbridge/
      deployment-failed.schema.json
    ai-agent/
      athena-summary.schema.json
      ai-recommendation.schema.json
    slack/
      first-alert.schema.json
      second-alert.schema.json
  docs/
    architecture.md
    runbook-design.md
    operation-guide.md
    troubleshooting.md
  tests/
    fixtures/
      prometheus-alerts.firing.json
      prometheus-alerts.normal.json
      athena-summary.sample.json
      deployment-failed.sample.json
```

## 3. 최상위 폴더 역할

| Folder | 역할 |
| --- | --- |
| `.github/workflows/` | 기존 배포 이후 실행할 Quality Gate workflow와 wrapper |
| `scripts/cd/` | rollout 확인, 선택적 GitOps/Argo CD 수동 운영 보조 도구 |
| `scripts/quality-gate/` | Prometheus 조회, 품질 게이트 판단, Slack 알림, EventBridge 발행 |
| `scripts/runbooks/` | alert별 대응 shell script |
| `lambda/analysis-orchestrator/` | EventBridge 이벤트를 받아 Athena와 AI 분석을 실행하는 Lambda |
| `ai-agent/` | Athena 결과와 Runbook을 기반으로 원인 분석과 대응 추천 생성 |
| `athena/` | Athena query, table schema, 서비스별 query template |
| `infra/` | AWS 리소스 IaC |
| `config/` | 서비스별 설정, 환경별 설정, threshold, dashboard mapping |
| `schemas/` | EventBridge, Slack, AI 결과 JSON schema |
| `docs/` | 운영/설계 문서 |
| `tests/` | 통합 테스트 fixture와 샘플 이벤트 |

## 4. GitHub Actions 파일

### `.github/workflows/cd.yml`

역할:

```text
기존 gympt-ops 배포 이후 Quality Gate workflow를 호출하는 wrapper
```

주요 step:

```text
1. workflow_dispatch 입력 수신
2. service/environment/namespace/deployment/image_tag 전달
3. .github/workflows/quality-gate.yml reusable workflow 호출
4. quality-gate.yml 내부에서 self-hosted runner로 rollout/Prometheus 검증
```

### `.github/workflows/quality-gate.yml`

역할:

```text
Prometheus alert 조회
Prometheus metric 조회
Quality Gate 평가
Grafana/Prometheus/Argo CD 링크 생성
Slack 1차 알림
EventBridge DeploymentFailed 이벤트 발행
```

## 5. CD Script 파일

### `scripts/cd/update-gitops-image-tag.sh`

GitOps repository의 Helm values 또는 Kustomize image tag를 새 image tag로 갱신하는 선택 보조 도구다.

현재 기본 통합 범위에서는 이 스크립트를 사용하지 않는다. GitOps values update는 기존 `gympt-ops` app CI/CD가 담당한다.

입력:

```text
SERVICE_NAME
ENVIRONMENT
IMAGE_TAG
GITOPS_REPO
VALUES_FILE
```

출력:

```text
GitOps commit SHA
변경된 image tag
```

### `scripts/cd/wait-argocd-app.sh`

Argo CD application sync와 health 상태를 대기하는 선택 도구다.

기존 `gympt-ops` 운영 흐름은 GitOps repository에 image tag를 push하고 Argo CD `syncPolicy.automated`가 자동 배포하도록 되어 있다. 이 저장소의 기본 경로는 그 이후 Quality Gate만 수행하므로 `cd.yml`에서 이 script를 호출하지 않는다.

사용 명령:

```text
argocd app sync
argocd app wait
argocd app get
```

### `scripts/cd/check-k8s-rollout.sh`

Kubernetes deployment rollout 상태를 확인한다.

사용 명령:

```text
kubectl rollout status deployment/<deployment-name>
kubectl get deploy
kubectl get pods
```

## 6. Quality Gate Script 파일

### `scripts/quality-gate/query-prometheus-alerts.sh`

Prometheus `/api/v1/alerts`를 호출해서 firing alert를 가져온다.

출력 예시:

```text
prometheus-alerts.json
```

### `scripts/quality-gate/query-prometheus-metrics.sh`

Prometheus `/api/v1/query` 또는 `/api/v1/query_range`를 호출해서 주요 metric을 조회한다.

조회 대상:

```text
5xx Error Rate
p95 Latency
Pod Restart Count
Unavailable Replicas
Readiness Probe Failure
```

### `scripts/quality-gate/evaluate-quality-gate.py`

Prometheus alert와 metric을 기준으로 CD 성공/실패를 판단한다.

입력:

```text
prometheus-alerts.json
prometheus-metrics.json
thresholds.yaml
alert-mapping.yaml
```

출력:

```text
quality-gate-result.json
```

출력 예시:

```json
{
  "status": "failed",
  "service": "backend-api",
  "environment": "prod",
  "failedRules": [
    "BackendHighErrorRate",
    "BackendHighLatency"
  ],
  "metrics": {
    "5xxErrorRate": "8.4%",
    "p95Latency": "2.8s",
    "podRestart": 3
  }
}
```

### `scripts/quality-gate/build-grafana-links.py`

서비스와 환경에 맞는 Grafana dashboard URL을 생성한다.

입력:

```text
SERVICE_NAME
ENVIRONMENT
DEPLOYED_AT
grafana-dashboards.yaml
```

출력:

```text
grafana-links.json
```

### `scripts/quality-gate/send-slack-first-alert.py`

배포 실패 1차 Slack 알림을 보낸다.

입력:

```text
quality-gate-result.json
grafana-links.json
argocdUrl
prometheusUrl
githubActionsRunUrl
```

### `scripts/quality-gate/publish-eventbridge-event.sh`

`DeploymentFailed` 이벤트를 EventBridge에 발행한다.

사용 명령:

```text
aws events put-events
```

## 7. Runbook Script 파일

`scripts/runbooks/`는 alert별 대응 shell script를 저장한다.

예시:

```text
backend-high-error-rate.sh
backend-high-latency.sh
pod-restarting.sh
db-connection-error.sh
waf-blocked-request-spike.sh
```

### `scripts/runbooks/backend-high-error-rate.sh`

목적:

```text
BackendHighErrorRate alert 발생 시 관련 로그와 상태를 빠르게 수집
```

수행 예시:

```text
kubectl get pods
kubectl logs
kubectl describe deploy
Athena ALB 5xx query 실행
최근 배포 image tag 확인
```

### `scripts/runbooks/pod-restarting.sh`

목적:

```text
Pod Restart 증가 시 CrashLoopBackOff, OOMKilled, probe failure 여부 확인
```

수행 예시:

```text
kubectl describe pod
kubectl logs --previous
kubectl get events
```

## 8. Lambda Orchestrator 파일

### `lambda/analysis-orchestrator/app.py`

역할:

```text
EventBridge DeploymentFailed 이벤트 수신
Athena query 실행
S3에 결과 저장
AI Agent 호출
Slack 2차 알림 전송
```

주요 함수:

```text
handler(event, context)
parse_deployment_failed_event(event)
start_athena_queries(detail)
wait_or_collect_query_results(query_ids)
write_summary_to_s3(summary)
invoke_ai_agent(summary)
send_second_slack_alert(result)
```

### `lambda/analysis-orchestrator/template.yaml`

SAM 기반 Lambda 배포 정의다.

포함 리소스:

```text
Lambda Function
EventBridge Rule
IAM Role
S3 access policy
Athena access policy
```

## 9. AI Agent 파일

### `ai-agent/app/main.py`

AI Agent 실행 진입점이다.

### `ai-agent/app/analyzer.py`

장애 분석 핵심 로직이다.

역할:

```text
Prometheus alert 해석
Athena summary 해석
Runbook 매칭
원인 후보 생성
대응 방안 선택
```

### `ai-agent/app/prompt_builder.py`

AI Agent에 전달할 prompt를 생성한다.

입력:

```text
deployment detail
prometheus alerts
athena summary
runbook scripts
grafana links
argocd link
```

### `ai-agent/app/runbook_loader.py`

alert 이름에 맞는 Runbook script 또는 문서를 로딩한다.

예시 mapping:

```text
BackendHighErrorRate -> scripts/runbooks/backend-high-error-rate.sh
BackendHighLatency -> scripts/runbooks/backend-high-latency.sh
BackendPodRestarting -> scripts/runbooks/pod-restarting.sh
```

### `ai-agent/app/slack_message_builder.py`

Slack 2차 알림 메시지를 생성한다.

### `ai-agent/app/schemas.py`

AI Agent 입력/출력 데이터 구조를 정의한다.

## 10. Athena 파일

### `athena/queries/*.sql`

실제 Athena에서 실행할 SQL 파일이다.

예시:

```text
alb-5xx-errors.sql
api-latency-top-paths.sql
waf-blocked-requests.sql
cloudfront-5xx-errors.sql
application-error-patterns.sql
```

### `athena/templates/*.json`

서비스별로 어떤 query를 실행할지 정의한다.

예시:

```json
{
  "service": "backend-api",
  "queries": [
    "alb-5xx-errors.sql",
    "api-latency-top-paths.sql",
    "application-error-patterns.sql"
  ],
  "windowMinutesBefore": 10,
  "windowMinutesAfter": 5
}
```

### `athena/schemas/*.sql`

Athena external table schema를 정의한다.

예시:

```text
alb_access_logs.sql
cloudfront_access_logs.sql
waf_logs.sql
application_logs.sql
```

## 11. Infra 파일

### `infra/terraform/eventbridge.tf`

EventBridge custom event rule과 target을 정의한다.

### `infra/terraform/lambda.tf`

Lambda function과 배포 패키지를 정의한다.

### `infra/terraform/iam.tf`

GitHub Actions, Lambda, Athena, S3 접근 권한을 정의한다.

### `infra/terraform/s3.tf`

로그 버킷, Athena 결과 버킷, deployment failure 결과 경로를 정의한다.

### `infra/terraform/athena.tf`

Athena database, workgroup, result location을 정의한다.

## 12. Config 파일

### `config/services/backend-api.yaml`

서비스별 배포 검증 대상과 alert mapping을 정의한다.

예시:

```yaml
service: backend-api
namespace: prod
deployment: backend-api
argocdApp: backend-api-prod
alerts:
  - BackendHighErrorRate
  - BackendHighLatency
  - BackendPodRestarting
dashboards:
  - backend-overview
  - jvm-metrics
```

### `config/quality-gate/thresholds.yaml`

Quality Gate threshold를 정의한다.

예시:

```yaml
backend-api:
  http5xxErrorRate: 5
  p95LatencySeconds: 2
  podRestartIncrease: 1
  unavailableReplicas: 0
```

### `config/quality-gate/alert-mapping.yaml`

Prometheus alert와 Runbook, 대응 후보를 연결한다.

예시:

```yaml
BackendHighErrorRate:
  runbook: scripts/runbooks/backend-high-error-rate.sh
  recommendedActions:
    - rollback
    - manual_fix
```

### `config/quality-gate/grafana-dashboards.yaml`

서비스별 dashboard URL template을 정의한다.

## 13. Schema 파일

### `schemas/eventbridge/deployment-failed.schema.json`

`DeploymentFailed` 이벤트 payload schema다.

### `schemas/ai-agent/athena-summary.schema.json`

Athena 분석 summary JSON schema다.

### `schemas/ai-agent/ai-recommendation.schema.json`

AI Agent 추천 결과 schema다.

### `schemas/slack/*.schema.json`

Slack 1차/2차 알림 메시지 구조를 정의한다.

## 14. Tests 파일

### `tests/fixtures/prometheus-alerts.firing.json`

Prometheus firing alert 테스트 fixture다.

### `tests/fixtures/prometheus-alerts.normal.json`

정상 상태 테스트 fixture다.

### `tests/fixtures/athena-summary.sample.json`

AI Agent 분석 테스트에 사용할 Athena summary 예시다.

### `tests/fixtures/deployment-failed.sample.json`

EventBridge Lambda handler 테스트에 사용할 sample event다.

## 15. 실제 실행 흐름과 파일 매핑

```text
Existing gympt-ops app CI/CD
  -> build/test
  -> ECR push
  -> GitOps values-dev/prod.yaml image tag update
  -> Argo CD automated sync
  -> EKS gympt-prod/backend-api-prod rollout

Post Deploy Quality Gate
  -> .github/workflows/cd.yml
  -> .github/workflows/quality-gate.yml
  -> scripts/cd/check-k8s-rollout.sh
  -> scripts/quality-gate/query-prometheus-alerts.sh
  -> scripts/quality-gate/query-prometheus-metrics.sh
  -> scripts/quality-gate/evaluate-quality-gate.py
  -> scripts/quality-gate/build-grafana-links.py

Failure Notification
  -> scripts/quality-gate/send-slack-first-alert.py
  -> scripts/quality-gate/publish-eventbridge-event.sh
  -> schemas/eventbridge/deployment-failed.schema.json

Async Analysis
  -> lambda/analysis-orchestrator/app.py
  -> athena/templates/backend-api.json
  -> athena/queries/*.sql
  -> S3 deployment-failures/*.json

AI Recommendation
  -> ai-agent/app/analyzer.py
  -> ai-agent/app/runbook_loader.py
  -> scripts/runbooks/*.sh
  -> ai-agent/app/slack_message_builder.py
```

## 16. 최소 구현 MVP 파일 세트

MVP 1차만 구현한다면 최소 파일은 다음과 같다.

```text
cd-quality-gate/
  .github/
    workflows/
      cd.yml
  scripts/
    quality-gate/
      query-prometheus-alerts.sh
      evaluate-quality-gate.py
      build-grafana-links.py
      send-slack-first-alert.py
  config/
    services/
      backend-api.yaml
    quality-gate/
      thresholds.yaml
      alert-mapping.yaml
      grafana-dashboards.yaml
```

MVP 2차까지 구현한다면 다음이 추가된다.

```text
scripts/
  quality-gate/
    publish-eventbridge-event.sh
lambda/
  analysis-orchestrator/
    app.py
    template.yaml
athena/
  queries/
    alb-5xx-errors.sql
    application-error-patterns.sql
  templates/
    backend-api.json
schemas/
  eventbridge/
    deployment-failed.schema.json
```

MVP 3차까지 구현한다면 다음이 추가된다.

```text
ai-agent/
  app/
    main.py
    analyzer.py
    prompt_builder.py
    runbook_loader.py
    slack_message_builder.py
    schemas.py
  prompts/
    incident-analysis-system.md
    incident-analysis-user-template.md
scripts/
  runbooks/
    backend-high-error-rate.sh
    backend-high-latency.sh
    pod-restarting.sh
```
