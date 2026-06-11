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
5. Terraform 기준 실제 배포 변수와 backend 연결값 확정
6. README에 work-log.md 링크 추가
```

### 2026-06-10 16:20 - work-log.md 생성

작업:

```text
작업 이력 추적을 위해 루트 work-log.md를 만들었다.
과거 작업은 파일 timestamp와 대화 흐름 기준으로 복원 기록했다.
README.md에 work-log.md 링크를 추가했다.
```

추가 파일:

```text
work-log.md
```

수정 파일:

```text
README.md
```

### 2026-06-10 16:30 - 실제 적용 결정 사항 반영

작업:

```text
ServiceMonitor/PrometheusRule namespace 정합성을 gympt-ops read-only로 확인했다.
backend-api-prod Quality Gate는 gympt-prod namespace 기준으로 평가하기로 확정했다.
EventBridge는 개인 프로젝트 전용 bus를 새로 쓰기로 했다.
Slack은 신규 #cd-deploy-alarm 채널을 사용하기로 했다.
Infra는 Terraform으로 관리하기로 했다.
AWS 리소스에는 비용 추적/stop 기준 tag를 넣도록 Terraform을 보강했다.
로컬 전체 검증 스크립트 scripts/test-local.sh를 추가했다.
```

gympt-ops read-only 확인:

```text
../gympt-ops/gympt-gitops/platform/monitoring/servicemonitor-backend-api.yaml
../gympt-ops/gympt-gitops/charts/backend-api/templates/servicemonitor.yaml
../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
../gympt-ops/gympt-gitops/platform/monitoring/rules/prometheusrule-backend.yaml
```

결론:

```text
static ServiceMonitor 파일은 backend-api namespace 기준이다.
하지만 chart template은 .Release.Namespace를 사용한다.
backend-api-prod destination namespace는 gympt-prod다.
PrometheusRule도 namespace="gympt-prod"를 조회한다.
따라서 Quality Gate는 gympt-prod 기준으로 설정한다.
```

추가 파일:

```text
scripts/quality-gate/send-slack-deploy-success.py
scripts/test-local.sh
```

수정 파일:

```text
.github/workflows/cd.yml
.github/workflows/quality-gate.yml
.github/workflows/cd-quality-gate-sample.yml
config/environments/dev.yaml
config/environments/prod.yaml
config/gympt-ops/connection-values.yaml
scripts/quality-gate/send-slack-first-alert.py
scripts/quality-gate/publish-eventbridge-event.sh
infra/terraform/providers.tf
infra/terraform/variables.tf
infra/terraform/main.tf
infra/terraform/s3.tf
infra/terraform/lambda.tf
infra/terraform/outputs.tf
docs/90-reference/16-gympt-ops-connection-map.md
README.md
.gitignore
```

확정값:

```text
EventBridge bus: cd-quality-gate-prod-bus
Slack channel: #cd-deploy-alarm
Infra: Terraform
AWS tag: Project=cd-quality-gate, Environment=dev/prod, CostControl=auto-stop
```

검증:

```text
scripts/test-local.sh 통과
terraform -chdir=infra/terraform fmt -check 통과
```

### 2026-06-10 17:14 - 로컬 테스트 재실행

사용자 요청으로 지금까지 만든 산출물을 다시 테스트했다.

실행한 검증:

```text
scripts/test-local.sh
terraform -chdir=infra/terraform fmt -check
GitHub Actions 및 config YAML 파싱 확인
tests/fixtures, schemas, athena/templates, lambda/analysis-orchestrator/events JSON 파싱 확인
python3 -m pytest lambda/analysis-orchestrator/tests -q
```

결과:

```text
scripts/test-local.sh 통과
terraform -chdir=infra/terraform fmt -check 통과
YAML 파싱 통과
JSON 파싱 통과
pytest는 현재 로컬 환경에 pytest 모듈이 없어 실행 불가
```

비고:

```text
Lambda/AI Agent 로컬 실행 경로는 scripts/test-local.sh 7단계에서 정상 동작 확인
```

### 2026-06-10 17:25 - 파일별 역할과 아키텍처 실행 흐름 문서 추가

작업:

```text
cd-quality-gate-ai-incident-analysis.drawio를 완성할 때 참고할 실행 흐름 문서를 추가했다.
yml, sh, py, tf, config yaml 파일이 각각 어떤 역할을 하는지 정리했다.
정상 배포, 실패 감지, EventBridge, Lambda, Athena, AI Agent, Slack 2차 알림까지 파일 실행 순서로 연결했다.
```

추가 파일:

```text
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
```

수정 파일:

```text
docs/20-implementation/README.md
docs/README.md
README.md
work-log.md
```

검증:

```text
GitHub Actions YAML 파싱 통과
scripts/cd/*.sh shell syntax 통과
scripts/test-local.sh 통과
terraform -chdir=infra/terraform fmt -check 통과
```

### 2026-06-11 00:00 - GitOps automated sync 기준 아키텍처 문서와 draw.io 업데이트

작업:

```text
GitHub Actions가 argocd app sync/wait를 직접 수행하는 표현을 제거했다.
GitOps values-prod.yaml image tag push 후 Argo CD backend-api-prod automated sync로 배포되는 흐름을 문서와 draw.io에 반영했다.
Prometheus는 외부 공개 URL이 아니라 self-hosted runner가 내부 service를 조회하는 구조로 표시했다.
DOC-31에 runtime architecture tree를 추가해 실행 주체, 파일, secret, output을 한 번에 따라갈 수 있게 정리했다.
DOC-13 tree 형식 아키텍처도 최신 실행 흐름으로 갱신했다.
```

수정 파일:

```text
cd-quality-gate-ai-incident-analysis.drawio
README.md
docs/10-architecture/04-architecture.md
docs/10-architecture/05-detailed-flows.md
docs/20-implementation/09-implementation-plan.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/90-reference/13-repository-architecture.md
work-log.md
```

검증:

```text
오래된 argocd sync/wait 표현 검색 결과 없음
draw.io 주요 라벨 GitOps automated sync 기준으로 변경 확인
GitHub Actions YAML 파싱 통과
scripts/test-local.sh 통과
terraform -chdir=infra/terraform fmt -check 통과
```

### 2026-06-11 00:00 - gympt-ops 방식에 맞춘 GitOps/Prometheus/Argo CD 결정 반영

작업:

```text
gympt-ops를 read-only로 확인해 배포 방식을 재정리했다.
gympt-app CI는 GITOPS_PAT로 hj-3/gympt-gitops main branch의 values-prod.yaml image tag를 직접 commit/push한다.
backend-api-prod Argo CD Application은 syncPolicy.automated로 Git 변경을 감지해 자동 배포한다.
Prometheus는 외부 공개 URL이 아니라 EKS 내부 kube-prometheus-stack service를 사용한다.
Quality Gate는 EKS/VPC 내부 self-hosted runner에서 실행하도록 맞췄다.
```

확정:

```text
GITOPS_REPO=hj-3/gympt-gitops
GitOps auth secret=GITOPS_PAT
PROMETHEUS_URL=http://kube-prometheus-stack-prometheus.monitoring.svc:9090
Quality Gate runner=[self-hosted, linux, eks]
Argo CD sync 방식=GitOps push 후 automated sync
```

수정 파일:

```text
.github/workflows/cd.yml
.github/workflows/quality-gate.yml
scripts/cd/update-gitops-image-tag.sh
docs/20-implementation/14-implementation-file-architecture.md
docs/20-implementation/15-github-actions-workflow-design.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
work-log.md
```

검증:

```text
Runtime File Role 문서 참조 확인
scripts/test-local.sh 통과
terraform -chdir=infra/terraform fmt -check 통과
```

### 2026-06-11 00:00 - GitHub Secrets와 runtime 값 정리 문서 추가

작업:

```text
실제 값 주입 전에 필요한 GitHub Secrets, GitHub Variables, AWS Secrets Manager 항목을 정리했다.
secret 원문은 문서에 기록하지 않고 입력 위치와 확인 방법만 기록하는 기준으로 작성했다.
GITOPS_PAT, PROMETHEUS_URL, SLACK_WEBHOOK_URL, AWS_ROLE_ARN을 우선 입력 대상으로 정리했다.
Prometheus 접근 방식, GitOps 인증 방식, Argo CD sync 방식은 gympt-ops 기준으로 확정했다.
```

추가 파일:

```text
docs/20-implementation/27-github-secrets-and-runtime-values.md
```

수정 파일:

```text
docs/20-implementation/README.md
docs/README.md
README.md
work-log.md
```

### 2026-06-11 14:37 - 배포 전체 구현이 아니라 post-deploy 확장 범위로 정정

작업:

```text
사용자 피드백 기준으로 범위를 다시 정리했다.
기존 gympt-ops가 build/test, ECR push, GitOps values update, Argo CD automated sync를 이미 담당한다는 점을 문서와 workflow에 반영했다.
cd-quality-gate-architecture는 기존 배포 이후 Quality Gate와 AI Incident Analysis만 추가하는 저장소로 정리했다.
이 저장소의 필수 GitHub Secret에서 GITOPS_PAT를 제외하고 PROMETHEUS_URL, SLACK_WEBHOOK_URL, AWS_ROLE_ARN만 남겼다.
cd-quality-gate-ai-incident-analysis.drawio의 GitHub/GitOps/Argo CD/EKS/Prometheus 라벨을 post-deploy Quality Gate 흐름에 맞췄다.
```

수정 파일:

```text
.github/workflows/cd.yml
README.md
cd-quality-gate-ai-incident-analysis.drawio
docs/00-overview/00-overview.md
docs/00-overview/01-old-vs-new.md
docs/00-overview/03-goals-and-scope.md
docs/10-architecture/04-architecture.md
docs/10-architecture/05-detailed-flows.md
docs/20-implementation/09-implementation-plan.md
docs/20-implementation/14-implementation-file-architecture.md
docs/20-implementation/15-github-actions-workflow-design.md
docs/20-implementation/22-test-and-validation-plan.md
docs/20-implementation/24-operations-runbook.md
docs/20-implementation/25-rollback-workflow-design.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
docs/90-reference/12-ids-and-terms.md
docs/90-reference/13-repository-architecture.md
work-log.md
```

주의:

```text
gympt-ops는 계속 read-only reference다.
scripts/cd/update-gitops-image-tag.sh는 선택 보조 도구로만 남긴다.
기본 실행 경로는 기존 배포 완료 후 .github/workflows/quality-gate.yml 실행이다.
```

검증:

```text
오래된 GitHub Actions CD/GitOps 직접 수행 표현 검색 후 핵심 문서 정정
GitHub Actions YAML 파싱 통과
scripts/test-local.sh 통과
terraform -chdir=infra/terraform fmt -check 통과
```

### 2026-06-11 14:54 - Slack 알림 채널명 변경

작업:

```text
Slack 알림 채널명을 #cicd-deploy-alarm에서 #cd-deploy-alarm으로 변경했다.
workflow, config, Terraform Lambda env/output, README, runtime 문서, secrets 문서, 로컬 테스트 스크립트의 채널명을 모두 맞췄다.
```

수정 파일:

```text
.github/workflows/quality-gate.yml
README.md
scripts/test-local.sh
config/environments/dev.yaml
config/environments/prod.yaml
config/gympt-ops/connection-values.yaml
infra/terraform/lambda.tf
infra/terraform/outputs.tf
docs/10-architecture/05-detailed-flows.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
docs/90-reference/13-repository-architecture.md
docs/90-reference/16-gympt-ops-connection-map.md
work-log.md
```

검증:

```text
이전 채널명 #cicd-deploy-alarm 검색 결과 없음
GitHub Actions YAML 파싱 통과
terraform -chdir=infra/terraform fmt -check 통과
```

### 2026-06-11 15:34 - Lambda analysis orchestrator zip 패키징

작업:

```text
Terraform apply 전에 필요한 Lambda 배포 zip을 생성하는 스크립트를 추가했다.
build/analysis-orchestrator.zip을 생성했다.
zip에는 app.py, ai_agent_adapter.py, athena query, athena template을 포함했다.
build/는 산출물이므로 .gitignore에 추가했다.
```

추가 파일:

```text
scripts/lambda/package-analysis-orchestrator.sh
```

수정 파일:

```text
.gitignore
README.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
work-log.md
```

생성 산출물:

```text
build/analysis-orchestrator.zip
```

검증:

```text
scripts/lambda/package-analysis-orchestrator.sh 실행 성공
unzip -l build/analysis-orchestrator.zip로 app.py, ai_agent_adapter.py, athena/queries, athena/templates 포함 확인
python3 -m py_compile로 Lambda Python 파일 컴파일 확인
```

### 2026-06-11 15:41 - Lambda와 ai-agent 실제 연결

작업:

```text
Lambda analysis orchestrator가 간단 adapter만 쓰지 않고 ai-agent 분석 모듈을 호출하도록 수정했다.
ai-agent analyzer가 Prometheus alert, Athena signal, runbook을 보고 원인 후보와 recommendedAction을 만든다.
Slack 2차 알림 payload에 cause candidates, recommended action, approval 필요 여부가 들어가도록 연결했다.
Lambda zip에 ai_agent 모듈과 scripts/runbooks를 포함하도록 패키징 스크립트를 수정했다.
```

수정 파일:

```text
lambda/analysis-orchestrator/ai_agent_adapter.py
lambda/analysis-orchestrator/app.py
scripts/lambda/package-analysis-orchestrator.sh
README.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
work-log.md
```

검증:

```text
scripts/lambda/package-analysis-orchestrator.sh 실행 성공
zip 안에 ai_agent/analyzer.py, ai_agent/runbook_loader.py, ai_agent/slack_message_builder.py 포함 확인
zip 안에 scripts/runbooks/*.sh 포함 확인
scripts/test-local.sh 통과
slack-second-alert.json에 원인 후보와 rollback 권장 조치 포함 확인
```

### 2026-06-11 15:52 - 승인 이벤트 workflow 추가

작업:

```text
rollback, DR, manual fix, change 승인 내용을 EventBridge에 남기는 workflow를 추가했다.
현재 단계는 승인 audit/event 발행까지이며, 실제 GitOps rollback 또는 DR 전환 실행기는 아직 연결하지 않는다.
approved-action.yml workflow_dispatch로 운영자가 승인 정보를 입력할 수 있게 했다.
DeploymentActionApproved 이벤트 스키마와 발행 스크립트를 추가했다.
로컬 테스트에 승인 이벤트 dry-run 생성을 포함했다.
```

추가 파일:

```text
.github/workflows/approved-action.yml
scripts/quality-gate/publish-approved-action-event.sh
schemas/eventbridge/deployment-action-approved.schema.json
```

수정 파일:

```text
.gitignore
README.md
docs/20-implementation/08-events-and-slack-messages.md
docs/20-implementation/25-rollback-workflow-design.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
scripts/test-local.sh
work-log.md
```

주의:

```text
Slack에서 rollback 또는 DR을 승인해도 아직 실제 rollback/DR 조치는 실행되지 않는다.
현재는 승인 이벤트를 EventBridge에 발행하고 artifact로 남기는 단계다.
실제 조치는 별도 executor workflow 또는 기존 gympt-ops 운영 흐름과 연결해야 한다.
```

### 2026-06-11 16:10 - Slack 승인 후 자동 action dispatch 구조 추가

작업:

```text
Slack 2차 알림에 Approve 버튼을 추가했다.
Slack interactivity 요청을 받는 slack-approval-handler Lambda를 추가했다.
승인 이벤트를 받으면 action type별 GitHub workflow를 자동 dispatch하는 deployment-action-executor Lambda를 추가했다.
API Gateway POST /slack/interactions를 Terraform에 추가했다.
DeploymentActionApproved EventBridge rule과 executor target을 Terraform에 추가했다.
패키징 스크립트가 analysis-orchestrator, slack-approval-handler, deployment-action-executor zip을 모두 생성하도록 수정했다.
```

추가 파일:

```text
lambda/slack-approval-handler/app.py
lambda/deployment-action-executor/app.py
infra/terraform/apigateway.tf
```

수정 파일:

```text
ai-agent/app/analyzer.py
ai-agent/app/slack_message_builder.py
infra/terraform/eventbridge.tf
infra/terraform/iam.tf
infra/terraform/lambda.tf
infra/terraform/outputs.tf
infra/terraform/variables.tf
scripts/lambda/package-analysis-orchestrator.sh
scripts/test-local.sh
README.md
docs/20-implementation/25-rollback-workflow-design.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
work-log.md
```

검증:

```text
scripts/lambda/package-analysis-orchestrator.sh 실행 성공
build/analysis-orchestrator.zip, build/slack-approval-handler.zip, build/deployment-action-executor.zip 생성 확인
scripts/test-local.sh 통과
terraform -chdir=infra/terraform fmt -check 통과
Slack 2차 알림 payload에 Approve rollback 버튼 포함 확인
```

### 2026-06-11 16:03 - 1차 Slack 알림 링크 보강

작업:

```text
CD Quality Gate 실패 1차 Slack 알림에 Grafana 링크만 있던 상태를 보강했다.
Prometheus alerts 링크와 Argo CD Application 링크를 grafana-links.json에 함께 생성한다.
send-slack-first-alert.py가 Grafana, Prometheus, Argo CD, GitHub Actions run 링크를 모두 메시지에 넣도록 수정했다.
```

수정 파일:

```text
.github/workflows/quality-gate.yml
scripts/quality-gate/build-grafana-links.py
scripts/quality-gate/send-slack-first-alert.py
scripts/test-local.sh
docs/20-implementation/08-events-and-slack-messages.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
work-log.md
```

검증:

```text
scripts/test-local.sh 통과
slack-first-alert.json에 Grafana, Prometheus Alerts, Argo CD 링크 포함 확인
GitHub Actions 링크는 실제 workflow 실행 시 GITHUB_RUN_URL 환경값으로 포함됨
```
