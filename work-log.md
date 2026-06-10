# Work Log

이 파일은 `cd-quality-gate-architecture` 작업 이력을 추적하기 위한 운영 기록이다.

목적:

```text
나중에 에러가 났을 때 어떤 파일을 언제 왜 만들었는지 빠르게 역추적한다.
gympt-ops는 참고만 했는지, 실제 수정했는지 구분한다.
설정값 변경, alert 이름 변경, workflow 변경, fixture 변경 근거를 남긴다.
```

기록 규칙:

```text
시간은 KST 기준 YYYY-MM-DD HH:MM 형식으로 기록한다.
작업은 "무엇을 했는지", "왜 했는지", "추가/수정/삭제 파일", "검증 결과"를 남긴다.
gympt-ops를 참고한 경우 반드시 "read-only"라고 명시한다.
실패하거나 되돌린 작업도 기록한다.
```

## 2026-06-09

### 2026-06-09 17:28 - 초기 문서 세트 정리

작업:

```text
CD Quality Gate와 AI Incident Analysis 구조를 설명하는 기본 markdown 문서 세트를 작성했다.
Overview, Architecture, Implementation, Presentation, Reference 섹션으로 분리했다.
```

추가/수정 파일:

```text
README.md
docs/README.md
docs/00-overview/00-overview.md
docs/00-overview/01-old-vs-new.md
docs/00-overview/02-background-and-problems.md
docs/00-overview/03-goals-and-scope.md
docs/10-architecture/04-architecture.md
docs/10-architecture/05-detailed-flows.md
docs/10-architecture/06-components.md
docs/20-implementation/08-events-and-slack-messages.md
docs/20-implementation/09-implementation-plan.md
docs/30-presentation/10-expected-effects.md
docs/30-presentation/11-presentation-notes.md
docs/90-reference/12-ids-and-terms.md
docs/90-reference/13-repository-architecture.md
```

비고:

```text
파일 timestamp 기준 17:28~17:50 사이에 문서 정리가 집중되어 있음.
```

### 2026-06-09 17:49 - 아키텍처 다이어그램 정리

작업:

```text
CD Quality Gate + AI Incident Analysis draw.io 다이어그램을 루트에 배치했다.
```

추가/수정 파일:

```text
cd-quality-gate-ai-incident-analysis.drawio
README.md
docs/10-architecture/04-architecture.md
```

## 2026-06-10

### 2026-06-10 14:00 - 추가 문서 후보 검토

작업:

```text
기존 docs 구조를 훑고, 추가하면 좋은 상세 설계 문서를 식별했다.
Lambda Orchestrator, Athena, AI Agent, Terraform, Test, Security, Demo 문서가 필요하다고 판단했다.
```

검토 기준:

```text
docs/20-implementation/14-implementation-file-architecture.md
docs/10-architecture/04-architecture.md
docs/10-architecture/05-detailed-flows.md
docs/10-architecture/06-components.md
```

### 2026-06-10 14:10 - DOC-18~DOC-24 추가

작업:

```text
구현 상세 설계와 발표 시나리오 문서를 추가했다.
```

추가 파일:

```text
docs/20-implementation/18-lambda-analysis-orchestrator-design.md
docs/20-implementation/19-athena-log-analysis-design.md
docs/20-implementation/20-ai-agent-prompt-and-output-design.md
docs/20-implementation/21-terraform-infra-design.md
docs/20-implementation/22-test-and-validation-plan.md
docs/20-implementation/23-security-and-iam-policy.md
docs/30-presentation/12-demo-scenario.md
```

수정 파일:

```text
README.md
docs/README.md
docs/20-implementation/README.md
docs/30-presentation/README.md
docs/90-reference/12-ids-and-terms.md
docs/90-reference/13-repository-architecture.md
```

### 2026-06-10 14:25 - DOC-25~DOC-29 추가

작업:

```text
실제 구현/운영에 필요한 참조 문서를 추가했다.
Configuration, Operations, Rollback, Data Schema, Limitations 문서를 만들었다.
```

추가 파일:

```text
docs/90-reference/14-configuration-reference.md
docs/20-implementation/24-operations-runbook.md
docs/20-implementation/25-rollback-workflow-design.md
docs/90-reference/15-data-schema-reference.md
docs/30-presentation/13-limitations-and-future-work.md
```

수정 파일:

```text
README.md
docs/README.md
docs/20-implementation/README.md
docs/30-presentation/README.md
docs/90-reference/README.md
docs/90-reference/12-ids-and-terms.md
docs/90-reference/13-repository-architecture.md
```

### 2026-06-10 14:40 - 루트 README 재구성

작업:

```text
모든 사람이 처음 읽는 진입점으로 README를 재작성했다.
gympt-ops는 참고용이며 직접 수정하지 않는다는 원칙을 명확히 적었다.
현재 구현 상태, 로컬 검증 방법, AWS 비용 절감 스크립트, 문서 읽는 순서를 추가했다.
```

수정 파일:

```text
README.md
```

### 2026-06-10 14:45 - MVP 1차 Quality Gate scaffold 추가

작업:

```text
Prometheus alert 조회, Quality Gate 평가, Grafana 링크 생성, Slack 1차 알림 payload 생성 흐름을 만들었다.
fixture 기반으로 외부 연동 없이 검증 가능하게 했다.
```

추가 파일:

```text
.github/workflows/cd-quality-gate-sample.yml
config/services/backend-api.yaml
config/quality-gate/thresholds.yaml
config/quality-gate/alert-mapping.yaml
config/quality-gate/grafana-dashboards.yaml
scripts/quality-gate/query-prometheus-alerts.sh
scripts/quality-gate/evaluate-quality-gate.py
scripts/quality-gate/build-grafana-links.py
scripts/quality-gate/send-slack-first-alert.py
tests/fixtures/prometheus-alerts.normal.json
tests/fixtures/prometheus-alerts.firing.json
.gitignore
```

검증:

```text
python3 -m py_compile 통과
normal fixture -> Quality Gate passed
firing fixture -> Quality Gate failed
Slack first alert dry-run payload 생성 확인
```

### 2026-06-10 14:55 - AWS 퇴근 전 비용 절감 스크립트 추가

작업:

```text
개인 실습 AWS 리소스를 퇴근 전에 stop/scale down하기 위한 스크립트를 추가했다.
기본 동작은 dry-run이며 --execute를 줘야 실제 실행된다.
Project=cd-quality-gate, Environment=dev tag 기준으로만 동작한다.
```

추가/수정 파일:

```text
scripts/aws/stop-after-work.sh
config/aws/stop-after-work.env.example
docs/20-implementation/24-operations-runbook.md
.gitignore
```

검증:

```text
bash -n scripts/aws/stop-after-work.sh 통과
scripts/aws/stop-after-work.sh --help 출력 확인
```

### 2026-06-10 15:00 - DOC-14 기준 전체 구현 scaffold 생성 시작

작업:

```text
docs/20-implementation/14-implementation-file-architecture.md, DOC-04, DOC-05, DOC-06을 기준으로 실제 파일 구조를 채우기 시작했다.
gympt-ops는 건드리지 않고 현재 repo 안에만 생성했다.
```

추가 파일:

```text
.github/workflows/cd.yml
.github/workflows/quality-gate.yml
scripts/cd/update-gitops-image-tag.sh
scripts/cd/wait-argocd-app.sh
scripts/cd/check-k8s-rollout.sh
scripts/quality-gate/query-prometheus-metrics.sh
scripts/quality-gate/publish-eventbridge-event.sh
```

### 2026-06-10 15:05 - Runbook, Lambda Orchestrator 추가

작업:

```text
alert별 runbook script와 EventBridge 이후 분석을 담당할 Lambda Orchestrator scaffold를 만들었다.
```

추가 파일:

```text
scripts/runbooks/backend-high-error-rate.sh
scripts/runbooks/backend-high-latency.sh
scripts/runbooks/pod-restarting.sh
scripts/runbooks/db-connection-error.sh
scripts/runbooks/waf-blocked-request-spike.sh
lambda/analysis-orchestrator/app.py
lambda/analysis-orchestrator/ai_agent_adapter.py
lambda/analysis-orchestrator/requirements.txt
lambda/analysis-orchestrator/template.yaml
lambda/analysis-orchestrator/events/deployment-failed.sample.json
lambda/analysis-orchestrator/tests/test_app.py
```

### 2026-06-10 15:06 - AI Agent 추가

작업:

```text
Athena summary와 Prometheus alert를 읽어 원인 후보와 추천 조치를 만드는 AI Agent scaffold를 추가했다.
```

추가 파일:

```text
ai-agent/app/main.py
ai-agent/app/analyzer.py
ai-agent/app/prompt_builder.py
ai-agent/app/runbook_loader.py
ai-agent/app/slack_message_builder.py
ai-agent/app/schemas.py
ai-agent/prompts/incident-analysis-system.md
ai-agent/prompts/incident-analysis-user-template.md
ai-agent/tests/test_analyzer.py
ai-agent/tests/test_slack_message_builder.py
ai-agent/requirements.txt
```

### 2026-06-10 15:07 - Athena, service/env config, fixture 추가

작업:

```text
Athena query, query template, external table schema를 추가했다.
서비스별 설정과 환경별 설정을 추가했다.
```

추가 파일:

```text
athena/queries/alb-5xx-errors.sql
athena/queries/api-latency-top-paths.sql
athena/queries/application-error-patterns.sql
athena/queries/cloudfront-5xx-errors.sql
athena/queries/waf-blocked-requests.sql
athena/templates/backend-api.json
athena/templates/posture-analysis-service.json
athena/templates/worker-lambda.json
athena/schemas/alb_access_logs.sql
athena/schemas/application_logs.sql
athena/schemas/cloudfront_access_logs.sql
athena/schemas/waf_logs.sql
config/services/posture-analysis-service.yaml
config/services/worker-lambda.yaml
config/environments/dev.yaml
config/environments/prod.yaml
tests/fixtures/prometheus-metrics.sample.json
tests/fixtures/athena-summary.sample.json
tests/fixtures/deployment-failed.sample.json
```

### 2026-06-10 15:08 - Infra/SAM/Schema scaffold 추가

작업:

```text
Terraform, SAM, JSON schema scaffold를 추가했다.
```

추가 파일:

```text
infra/terraform/providers.tf
infra/terraform/variables.tf
infra/terraform/main.tf
infra/terraform/s3.tf
infra/terraform/eventbridge.tf
infra/terraform/iam.tf
infra/terraform/lambda.tf
infra/terraform/athena.tf
infra/terraform/slack.tf
infra/terraform/outputs.tf
infra/sam/template.yaml
schemas/eventbridge/deployment-failed.schema.json
schemas/ai-agent/athena-summary.schema.json
schemas/ai-agent/ai-recommendation.schema.json
schemas/slack/first-alert.schema.json
schemas/slack/second-alert.schema.json
schemas/rollback/rollback-request.schema.json
```

### 2026-06-10 15:09 - 운영 문서 진입점 추가

작업:

```text
실제 구현자가 빠르게 들어갈 수 있는 root docs entrypoint를 추가했다.
```

추가 파일:

```text
docs/architecture.md
docs/runbook-design.md
docs/operation-guide.md
docs/troubleshooting.md
```

수정 파일:

```text
config/quality-gate/thresholds.yaml
config/quality-gate/alert-mapping.yaml
config/quality-gate/grafana-dashboards.yaml
```

### 2026-06-10 15:10 - 전체 scaffold 검증

검증:

```text
bash -n scripts/cd/*.sh scripts/quality-gate/*.sh scripts/runbooks/*.sh scripts/aws/*.sh
python3 -m py_compile scripts/quality-gate/*.py lambda/analysis-orchestrator/*.py ai-agent/app/*.py
python3 -m json.tool schemas/*.json 및 fixture JSON
```

결과:

```text
Shell syntax 통과
Python compile 통과
JSON parsing 통과
Quality Gate 실패 fixture -> 실패 처리 정상
Slack first alert payload 생성 정상
EventBridge payload dry-run 생성 정상
AI Agent 분석 결과 생성 정상
Lambda local sample 실행 정상
```

### 2026-06-10 15:16 - cicd_monitoring_flow visual draw.io 시도

작업:

```text
기존 cicd_monitoring_flow.drawio를 참고해 이미지 중심 새 draw.io 파일을 만들었다.
```

추가 파일:

```text
cicd_monitoring_flow_visual.drawio
```

수정 파일:

```text
README.md
docs/10-architecture/04-architecture.md
```

### 2026-06-10 15:26 - cicd_monitoring_flow visual 작업 되돌림

작업:

```text
사용자 판단에 따라 새 visual draw.io가 이상하다고 보고 삭제/링크 제거했다.
기존 cicd_monitoring_flow.drawio는 참고용으로 그대로 유지했다.
```

삭제 파일:

```text
cicd_monitoring_flow_visual.drawio
```

수정 파일:

```text
README.md
docs/10-architecture/04-architecture.md
```

검증:

```text
README.md와 docs/10-architecture/04-architecture.md에 visual 링크가 남아 있지 않음.
현재 draw.io 파일은 cd-quality-gate-ai-incident-analysis.drawio, cicd_monitoring_flow.drawio 두 개만 남음.
```

### 2026-06-10 15:31 - gympt-ops 연결값 조사

작업:

```text
gympt-ops를 read-only로 참고해서 실제 서비스 연결값을 조사했다.
조사 결과를 현재 repo 안에 문서와 config 후보로 정리했다.
gympt-ops 파일은 수정하지 않았다.
```

참고한 위치:

```text
../gympt-ops/gympt-app
../gympt-ops/gympt-gitops
../gympt-ops/gympt-infra
```

추가 파일:

```text
docs/90-reference/16-gympt-ops-connection-map.md
config/gympt-ops/connection-values.yaml
```

수정 파일:

```text
README.md
docs/README.md
docs/90-reference/README.md
docs/90-reference/12-ids-and-terms.md
docs/90-reference/13-repository-architecture.md
```

확인한 주요 값:

```text
backend-api-prod -> namespace gympt-prod, chart charts/backend-api, values-prod.yaml
backend-api-dev -> namespace backend-api, chart charts/backend-api, values-dev.yaml
Prometheus internal URL -> http://kube-prometheus-stack-prometheus.monitoring.svc:9090
Grafana host -> https://grafana.g2mpt.com
Athena database -> gympt_prod_catalog
Athena workgroup -> gympt-prod-workgroup
Athena output -> s3://gympt-prod-athena-results-337112169365/athena-results/
```

검증:

```text
gympt-ops git status 출력 없음 -> read-only 유지 확인.
```

### 2026-06-10 16:13 - backend-api-prod 기준 설정 보정

작업:

```text
우리 scaffold를 gympt-ops 실제 backend-api-prod 연결값에 맞췄다.
```

수정 파일:

```text
config/services/backend-api.yaml
config/quality-gate/alert-mapping.yaml
config/quality-gate/grafana-dashboards.yaml
.github/workflows/quality-gate.yml
.github/workflows/cd-quality-gate-sample.yml
```

변경 내용:

```text
namespace: prod -> gympt-prod
deployment: backend-api -> backend-api-prod
argocdApp: backend-api-prod 유지
chartPath: charts/backend-api 추가
valuesFile: values-prod.yaml 추가
imageRepository: 337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api 추가
Grafana baseUrl: https://grafana.g2mpt.com
dashboard UID: api-latency, jvm-metrics, eks-overview, athena-security-logs
```

### 2026-06-10 16:14 - 실제 PrometheusRule alert 기준 보정

작업:

```text
gympt-ops의 실제 backend-api PrometheusRule에 맞춰 alert/runbook/fixture를 보정했다.
```

추가 파일:

```text
scripts/runbooks/backend-db-pool-exhaustion.sh
scripts/runbooks/backend-high-memory-usage.sh
```

수정 파일:

```text
ai-agent/app/runbook_loader.py
tests/fixtures/prometheus-alerts.firing.json
tests/fixtures/prometheus-metrics.sample.json
tests/fixtures/deployment-failed.sample.json
tests/fixtures/athena-summary.sample.json
lambda/analysis-orchestrator/events/deployment-failed.sample.json
```

변경 내용:

```text
DBConnectionError 대신 BackendDBPoolExhaustion 사용
BackendHighMemoryUsage 추가
firing fixture namespace를 gympt-prod로 변경
Lambda sample Grafana URL을 https://grafana.g2mpt.com/d/api-latency... 로 변경
```

검증:

```text
python3 -m json.tool fixture JSON 통과
bash -n new runbook scripts 통과
python3 -m py_compile ai-agent mapping 관련 파일 통과
Quality Gate 평가:
  scripts/quality-gate/evaluate-quality-gate.py --alerts-file tests/fixtures/prometheus-alerts.firing.json --service backend-api --namespace gympt-prod ...
  -> Quality Gate failed: 3 firing alert(s) matched.
AI Agent sample 실행 통과
```

## 현재 기준 중요 파일

설정:

```text
config/gympt-ops/connection-values.yaml
config/services/backend-api.yaml
config/quality-gate/alert-mapping.yaml
config/quality-gate/grafana-dashboards.yaml
```

workflow:

```text
.github/workflows/cd.yml
.github/workflows/quality-gate.yml
.github/workflows/cd-quality-gate-sample.yml
```

핵심 script:

```text
scripts/quality-gate/query-prometheus-alerts.sh
scripts/quality-gate/query-prometheus-metrics.sh
scripts/quality-gate/evaluate-quality-gate.py
scripts/quality-gate/build-grafana-links.py
scripts/quality-gate/send-slack-first-alert.py
scripts/quality-gate/publish-eventbridge-event.sh
scripts/aws/stop-after-work.sh
```

장애 분석:

```text
lambda/analysis-orchestrator/app.py
ai-agent/app/analyzer.py
ai-agent/app/runbook_loader.py
athena/templates/backend-api.json
athena/queries/*.sql
```

조사/참조:

```text
docs/90-reference/16-gympt-ops-connection-map.md
docs/20-implementation/14-implementation-file-architecture.md
docs/10-architecture/04-architecture.md
docs/10-architecture/05-detailed-flows.md
docs/10-architecture/06-components.md
```

## 다음 작업 후보

```text
1. backend-api-prod 설정 기준으로 quality-gate workflow를 실제 실행 가능한 입력값 형태로 더 정리
2. ServiceMonitor namespace와 prod namespace 정합성 추가 확인
3. EventBridge bus를 기존 gympt EventBridge와 공유할지 별도 생성할지 결정
4. Slack 1차 알림 채널을 기존 Alertmanager 채널과 분리할지 결정
5. Terraform/SAM 중 실제 배포 방식을 하나로 선택
6. README에 work-log.md 링크 추가
```

