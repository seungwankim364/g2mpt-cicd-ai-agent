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

## 2026-06-16

### 2026-06-16 12:45 - gympt-apps부터 cd-quality-gate까지 상세 흐름 문서 추가

작업:

```text
gympt-apps -> gympt-gitops -> cd-quality-gate-architecture 전체 흐름을 한 문서에서 이해할 수 있도록 DOC-36을 추가했다.
정상 배포, Quality Gate 성공, Quality Gate 실패, EventBridge, Lambda AI 분석, Slack 승인, rollback 직접 GitOps push 흐름을 단계별로 정리했다.
각 단계에서 실행되는 repo, workflow, script, Lambda, Terraform 파일을 연결했다.
```

추가 파일:

```text
docs/20-implementation/31-gympt-app-to-gitops-to-quality-gate-flow.md
```

수정 파일:

```text
README.md
docs/README.md
docs/20-implementation/README.md
work-log.md
```

검증:

```text
DOC-31 Runtime File Role and Architecture Flow와 중복되지 않게, DOC-36은 repo 간 end-to-end 흐름 중심으로 작성했다.
현재 확정된 rollback 방식인 cd-quality-gate 직접 gympt-gitops values tag 수정 기준으로 작성했다.
```

### 2026-06-16 12:35 - 새 GitHub PAT 권한 확인

작업:

```text
사용자가 classic PAT를 repo scope로 재발급하고 AWS Secrets Manager와 GitHub Secret에 반영했다.
AWS Secrets Manager cd-quality-gate/github/dispatch-token 값을 직접 출력하지 않고 GitHub API 권한만 확인했다.
실제 rollback workflow는 실행하지 않고, 존재하지 않는 ref로 workflow_dispatch API를 호출해 권한을 비파괴 검증했다.
```

확인 결과:

```text
AWS Secrets Manager token prefix: ghp_
GitHub token scope: repo
GitHub user: seungwankim364
seungwankim364/g2mpt-cicd-ai-agent permissions: admin true, push true
hj-3/gympt-gitops permissions: push true
cd-quality-gate rollback workflow: active
cd-quality-gate GH_WORKFLOW_DISPATCH_TOKEN secret name: exists
workflow_dispatch invalid ref check: HTTP 422 No ref found
```

판단:

```text
HTTP 422는 workflow_dispatch 권한은 통과했고 ref만 없다는 뜻이므로 dispatch 권한 확인으로 본다.
GitHub Secret 값은 API로 읽을 수 없지만, secret 이름은 존재한다.
사용자가 같은 PAT를 GH_WORKFLOW_DISPATCH_TOKEN에 넣었다면 rollback.yml이 gympt-gitops에 직접 push할 권한 조건은 충족된다.
```

### 2026-06-16 12:05 - rollback을 cd-quality-gate 직접 GitOps push 방식으로 변경

작업:

```text
사용자가 hj-3/gympt-gitops collaborator 권한을 갖고 직접 push/pull 가능하다는 전제로 rollback 구조를 다시 정리했다.
gympt-gitops에 별도 rollback workflow를 두지 않고, cd-quality-gate의 rollback.yml이 gympt-gitops values-prod.yaml image.tag를 직접 이전 tag로 갱신하도록 변경했다.
rollback은 새 이미지를 빌드하는 작업이 아니므로 gympt-app 배포 workflow 재실행 step을 제거했다.
gympt-gitops에 추가했던 rollback workflow 파일은 삭제했다.
integration-templates/gympt-gitops rollback workflow 템플릿도 삭제했다.
```

수정 파일:

```text
.github/workflows/rollback.yml
infra/terraform/variables.tf
README.md
docs/20-implementation/25-rollback-workflow-design.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
docs/20-implementation/28-pre-apply-verification-checklist.md
docs/20-implementation/30-final-status-and-user-checklist.md
dashboard/src/data/sample-dashboard.js
work-log.md
```

삭제 파일:

```text
../gympt-ops/gympt-gitops/.github/workflows/rollback.yml
integration-templates/gympt-gitops/.github/workflows/rollback.yml
```

권한 기준:

```text
AWS Secrets Manager cd-quality-gate/github/dispatch-token:
  - seungwankim364/g2mpt-cicd-ai-agent Actions read/write 필요
  - deployment-action-executor가 cd-quality-gate rollback.yml을 dispatch하기 위해 사용

cd-quality-gate GitHub Secret GH_WORKFLOW_DISPATCH_TOKEN:
  - hj-3/gympt-gitops Contents read/write 필요
  - rollback.yml이 values-prod.yaml image.tag를 직접 commit/push하기 위해 사용
```

주의:

```text
팀원 repo인 gympt-gitops에는 rollback workflow를 유지하지 않는다.
대신 사용자 PAT/collaborator 권한으로 cd-quality-gate workflow가 GitOps values를 직접 수정한다.
```

### 2026-06-16 11:50 - GitHub dispatch token 권한과 Secret 형식 확인

작업:

```text
AWS Secrets Manager의 cd-quality-gate/github/dispatch-token 값을 직접 출력하지 않고 형식만 확인했다.
SecretString은 순수 PAT 문자열이 아니라 JSON 형태이며 key는 cd-quality-gate/github/dispatch-token이다.
기존 deployment-action-executor는 SecretString 전체를 token으로 사용하므로 GitHub API 호출 시 401이 날 수 있음을 확인했다.
deployment-action-executor가 JSON secret을 파싱하고 단일 key secret 값도 token으로 사용할 수 있게 수정했다.
GitHub API로 hj-3/gympt-gitops repo와 rollback workflow 조회를 확인했다.
실제 workflow를 실행하지 않기 위해 존재하지 않는 ref로 workflow_dispatch 권한을 확인했다.
```

확인 결과:

```text
GitHub token user: seungwankim364
hj-3/gympt-gitops repo 조회: 성공
hj-3/gympt-gitops rollback workflow 조회: 성공, state active
hj-3/gympt-gitops permissions: push true, pull true
workflow_dispatch permission check: 실패, HTTP 403 Resource not accessible by personal access token
gympt-gitops actions secrets list: 실패, HTTP 403
cd-quality-gate actions secrets list: 실패, HTTP 403
```

수정 파일:

```text
lambda/deployment-action-executor/app.py
work-log.md
```

남은 일:

```text
AWS Secrets Manager cd-quality-gate/github/dispatch-token 값을 workflow_dispatch 가능한 token으로 교체해야 한다.
토큰에는 hj-3/gympt-gitops Actions workflow dispatch 권한이 필요하다.
gympt-gitops 안의 GITOPS_PAT 존재 여부는 현재 token으로 API 조회가 불가능하므로 GitHub UI에서 확인해야 한다.
```

### 2026-06-16 11:20 - 서비스 테스트 전 사전 체크리스트를 plan 기준으로 정리

작업:

```text
서비스를 다시 띄우기 전 할 수 있는 작업을 Terraform plan까지만으로 제한했다.
terraform apply는 사전 작업 범위에서 제외했다.
Lambda zip 3개를 최신 코드 기준으로 다시 생성했다.
terraform fmt -check와 terraform validate를 확인했다.
terraform plan -out=tfplan은 AWS profile ksw2 session expired 때문에 완료하지 못했다.
```

실행 결과:

```text
scripts/lambda/package-analysis-orchestrator.sh 성공
terraform -chdir=infra/terraform fmt -check 최초 실패: terraform.tfvars formatting
terraform -chdir=infra/terraform fmt 실행: 값 변경 없이 formatting 반영
terraform -chdir=infra/terraform fmt -check 통과
terraform -chdir=infra/terraform validate 통과
terraform -chdir=infra/terraform plan -out=tfplan 실패: No valid credential sources found
aws sts get-caller-identity --profile ksw2 실패: session expired, aws login 필요
terraform -chdir=infra/terraform plan -refresh=false -out=tfplan 실패: provider credential 필요
```

수정 파일:

```text
build/analysis-orchestrator.zip
build/slack-approval-handler.zip
build/deployment-action-executor.zip
infra/terraform/terraform.tfvars
docs/20-implementation/30-final-status-and-user-checklist.md
work-log.md
```

남은 일:

```text
aws login으로 ksw2 profile 재인증
AWS_PROFILE=ksw2 terraform -chdir=infra/terraform plan -out=tfplan 재실행
apply는 아직 실행하지 않음
```

### 2026-06-16 11:35 - Terraform plan 완료

작업:

```text
사용자가 aws login을 완료한 뒤 Terraform plan을 다시 실행했다.
AWS_PROFILE=ksw2만으로는 Terraform provider가 credential을 읽지 못해 AWS CLI export-credentials를 같은 쉘에 주입해 plan을 실행했다.
terraform apply는 실행하지 않았다.
```

실행 결과:

```text
terraform -chdir=infra/terraform plan -out=tfplan 성공
Plan: 28 to add, 0 to change, 0 to destroy
Saved the plan to: tfplan
```

생성 예정 범위:

```text
API Gateway Slack interactivity endpoint
Athena database/workgroup
EventBridge bus/rules/targets
IAM roles/policies
Lambda 3개
Lambda permissions
S3 result bucket and bucket controls
Secrets Manager slack webhook secret resource
```

확인된 주요 output:

```text
event_bus_name: cd-quality-gate-prod-bus
lambda_function_name: cd-quality-gate-prod-analysis-orchestrator
result_bucket_name: cd-quality-gate-prod-results
athena_database_name: cd_quality_gate_prod_logs
athena_workgroup_name: cd-quality-gate-prod-workgroup
slack_interactivity_url: known after apply
```

주의:

```text
tfplan 파일은 생성됐지만 apply는 아직 하지 않는다.
실제 AWS 리소스는 아직 생성되지 않았다.
```

### 2026-06-16 11:05 - gympt-gitops rollback workflow 실제 추가

작업:

```text
사용자 확인 후, 기존 PAT가 gympt-gitops에 있으므로 실제 rollback workflow를 gympt-gitops에 추가했다.
추가한 workflow는 workflow_dispatch 전용이라 push/merge만으로 자동 실행되지 않는다.
실행될 때만 charts/backend-api/values-prod.yaml image.tag를 target_image_tag로 변경하고 commit/push한다.
```

추가 파일:

```text
../gympt-ops/gympt-gitops/.github/workflows/rollback.yml
```

수정 파일:

```text
README.md
docs/20-implementation/25-rollback-workflow-design.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
docs/20-implementation/28-pre-apply-verification-checklist.md
docs/20-implementation/30-final-status-and-user-checklist.md
work-log.md
```

영향:

```text
자동 실행 트리거가 없으므로 팀원 서비스에는 즉시 영향 없음.
Slack 승인 또는 GitHub workflow_dispatch로 호출될 때만 prod values image tag를 변경함.
GITOPS_PAT 권한과 target_image_tag 입력값이 잘못되면 rollback workflow가 실패하거나 잘못된 tag로 rollback될 수 있으므로 실제 호출 전 smoke test가 필요함.
```

검증:

```text
gympt-gitops rollback workflow YAML parse 통과
gympt-gitops git status 기준 신규 파일은 .github/workflows/rollback.yml 하나
```

### 2026-06-16 10:45 - gympt-gitops rollback workflow 부재 반영

작업:

```text
../gympt-ops/gympt-gitops를 read-only로 확인했다.
gympt-gitops에는 .github/workflows 디렉터리와 rollback.yml이 없음을 확인했다.
기존 rollback.yml이 "기존 GitOps rollback workflow dispatch"를 전제로 하던 부분을 재검토했다.
사용자 확인 결과 PAT는 이미 gympt-gitops repo에 있으므로, cd-quality-gate가 GitOps values를 직접 push하는 방식은 맞지 않다고 판단했다.
rollback dispatch 대상 기본값을 hj-3/gympt-gitops로 맞췄다.
나중에 gympt-gitops에 붙일 rollback workflow 템플릿을 integration-templates/gympt-gitops/.github/workflows/rollback.yml에 추가했다.
```

수정 파일:

```text
.github/workflows/rollback.yml
README.md
docs/20-implementation/25-rollback-workflow-design.md
docs/20-implementation/28-pre-apply-verification-checklist.md
docs/20-implementation/30-final-status-and-user-checklist.md
dashboard/src/data/sample-dashboard.js
integration-templates/gympt-gitops/.github/workflows/rollback.yml
work-log.md
```

주의:

```text
gympt-ops 파일은 수정하지 않았다.
cd-quality-gate의 GitHub dispatch token은 hj-3/gympt-gitops rollback workflow를 호출할 수 있어야 한다.
실제 values commit은 gympt-gitops repo 안의 기존 GITOPS_PAT가 수행한다.
DR은 여전히 실제 DR workflow 또는 명령 연결이 필요하다.
```

### 2026-06-16 10:30 - 최종 상태와 사용자 체크리스트 문서 추가

작업:

```text
현재까지 파일 기준으로 확실히 완료된 항목과 아직 live 검증이 필요한 항목을 분리했다.
기존 체크리스트 문서가 apply 전 점검과 dashboard 전용으로 나뉘어 있어, 전체 상태를 한눈에 보는 최종 체크리스트를 DOC-35로 추가했다.
사용자가 해야 할 일, AWS 재생성 시 할 일, 서비스 복구 후 할 일, 퇴근 전 destroy 확인 항목을 분리했다.
```

추가 파일:

```text
docs/20-implementation/30-final-status-and-user-checklist.md
```

수정 파일:

```text
README.md
docs/README.md
docs/20-implementation/README.md
work-log.md
```

검증:

```text
기존 DOC-33, DOC-34와 역할이 겹치지 않도록 확인했다.
DOC-35는 최종 상태 요약과 사용자 액션 체크리스트 역할로 분리했다.
```

### 2026-06-16 10:17 - Dashboard local backend와 버튼 action 연결

작업:

```text
아키텍처 흐름도 위치를 재확인했다.
실제 draw.io 다이어그램은 cd-quality-gate-ai-incident-analysis.drawio이고, 파일 실행 기준 흐름은 docs/20-implementation/26-runtime-file-role-and-architecture-flow.md가 기준이다.
dashboard/server.mjs local backend를 추가해 정적 dashboard와 API를 함께 제공하도록 구성했다.
GET /api/dashboard, GET /api/actions, POST /api/actions, POST /api/infra/apply-plan, POST /api/infra/destroy-plan을 추가했다.
대시보드 기본 data adapter를 /api/dashboard 우선으로 변경하고, backend가 없으면 demo fallback으로 동작하도록 유지했다.
Approval & Action 영역에 rollback/dr/manual_fix/change 기록 버튼을 연결했다.
Infra & Cost 영역에 apply plan, destroy plan 버튼을 연결했다.
버튼은 실제 AWS/GitHub 작업을 직접 실행하지 않고 dashboard/runtime/actions.json에 action record와 dispatch payload를 남기는 안전한 local control-plane으로 구현했다.
Runtime File Role and Architecture Flow에 dashboard-control-center tree와 draw.io 영역 매핑을 추가했다.
Dashboard Control Center Checklist 문서를 추가했다.
```

추가 파일:

```text
dashboard/server.mjs
docs/20-implementation/29-dashboard-control-center-checklist.md
```

수정 파일:

```text
.gitignore
README.md
dashboard/README.md
dashboard/data-contracts/dashboard-data.schema.json
dashboard/src/data/loadDashboardData.js
dashboard/src/main.js
dashboard/src/styles.css
docs/README.md
docs/20-implementation/README.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/90-reference/13-repository-architecture.md
scripts/test-local.sh
work-log.md
```

검증:

```text
node --check dashboard/server.mjs 통과
node --check dashboard/src/main.js 통과
node --check dashboard/src/data/loadDashboardData.js 통과
python3 -m json.tool dashboard/data-contracts/dashboard-data.schema.json 통과
scripts/test-local.sh 통과
node dashboard/server.mjs 실행 중: http://localhost:5173
```

주의:

```text
현재 dashboard 버튼은 안전한 기록/plan 버튼이다.
실제 rollback/DR/change 실행은 Slack 승인 -> API Gateway -> EventBridge -> deployment-action-executor -> GitHub workflow dispatch 경로로 검증한다.
live 운영 데이터 연결은 서비스와 AWS stack이 올라온 뒤 dashboard-data.json 생성 또는 API adapter 연결 단계에서 진행한다.
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

### 2026-06-11 16:18 - 승인 action 대상 workflow 4개 추가

작업:

```text
deployment-action-executor가 같은 repo에서 dispatch할 rollback/dr/manual_fix/change workflow를 추가했다.
rollback.yml은 승인된 target_image_tag를 기존 GitOps/gympt-ops rollback workflow에 전달한다.
dr-failover.yml은 DR 승인 실행 기록을 생성하고 실제 DR 명령 연결 지점을 남긴다.
manual-fix.yml은 수동 조치 이슈와 실행 기록을 생성한다.
change-apply.yml은 승인된 change 실행 기록과 이슈를 생성한다.
Terraform workflow repo 기본값을 seungwankim364/g2mpt-cicd-ai-agent로 설정했다.
```

추가 파일:

```text
.github/workflows/rollback.yml
.github/workflows/dr-failover.yml
.github/workflows/manual-fix.yml
.github/workflows/change-apply.yml
```

주의:

```text
rollback.yml이 기존 rollback workflow를 호출하려면 이 repo GitHub Secret에 GH_WORKFLOW_DISPATCH_TOKEN이 필요하다.
GitOps push용 GITOPS_PAT는 기존 GitOps/gympt-ops repo에 있는 값을 사용한다.
DR 전환은 서비스별 실제 DR 명령이 정해지면 dr-failover.yml에 연결한다.
```

### 2026-06-11 16:25 - rollback이 이 repo에서 GitOps를 직접 수정하지 않도록 정정

작업:

```text
기존 GitOps repo에 GITOPS_PAT가 이미 있으므로, 이 repo에 GITOPS_PAT를 추가하지 않는 방향으로 rollback.yml을 수정했다.
rollback.yml은 GitOps values를 직접 수정하지 않고, 기존 GitOps/gympt-ops rollback workflow를 dispatch한다.
문서에서 이 repo에 GITOPS_PAT가 필요하다는 문구를 제거하고 GH_WORKFLOW_DISPATCH_TOKEN 필요 조건으로 바꿨다.
```

### 2026-06-11 16:47 - 조치 후 gympt-app 배포 workflow 재실행 연결

작업:

```text
rollback, DR, manual fix, change 승인 workflow가 조치 후 기존 gympt-app 배포 workflow를 다시 dispatch하도록 연결했다.
deployment-action-executor가 app_repo, app_workflow, app_ref 값을 action workflow에 전달하도록 수정했다.
공통 GitHub workflow dispatch 스크립트를 추가했다.
배포 완료 Slack 알림은 gympt-app 배포 workflow가 마지막에 quality-gate.yml을 호출하는 계약으로 정리했다.
```

추가 파일:

```text
scripts/github/dispatch-workflow.py
```

수정 파일:

```text
.github/workflows/rollback.yml
.github/workflows/dr-failover.yml
.github/workflows/manual-fix.yml
.github/workflows/change-apply.yml
lambda/deployment-action-executor/app.py
infra/terraform/lambda.tf
infra/terraform/variables.tf
README.md
docs/20-implementation/25-rollback-workflow-design.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
work-log.md
```

주의:

```text
gympt-app 배포 workflow는 workflow_dispatch 입력을 받아야 한다.
gympt-app 배포 workflow 마지막에는 cd-quality-gate-architecture의 quality-gate.yml 호출이 있어야 Slack 배포 완료 알림까지 이어진다.
```

### 2026-06-12 15:11 - Terraform destroy 기반 퇴근 전 비용 정리로 전환

작업:

```text
Lambda, S3, Athena, EventBridge, API Gateway는 stop 개념이 없으므로 비용 정리 방식을 Terraform destroy 기준으로 바꿨다.
기존 수동 생성 Slack webhook secret은 terraform state rm으로 state에서 제거해 destroy 대상에서 제외했다.
Terraform destroy를 실행해 cd-quality-gate-prod stack 리소스를 삭제했다.
S3 result bucket 안에 Athena 결과 객체 2개가 있어 bucket 삭제가 실패했으므로, cd-quality-gate-prod-results bucket 내부 객체만 비운 뒤 destroy를 재실행했다.
퇴근 전 정리용 스크립트를 stop/scale down 방식이 아니라 Terraform destroy 방식으로 새로 추가했다.
README와 운영 문서의 비용 절감 절차를 destroy 기준으로 갱신했다.
```

추가 파일:

```text
scripts/aws/destroy-terraform-stack.sh
```

수정 파일:

```text
README.md
docs/operation-guide.md
docs/20-implementation/24-operations-runbook.md
scripts/test-local.sh
work-log.md
```

삭제 검증:

```text
terraform state list 결과 0개
cd-quality-gate-prod-analysis-orchestrator Lambda 조회 실패 확인
cd-quality-gate-prod-bus EventBridge bus 조회 실패 확인
cd-quality-gate-prod-results S3 bucket 조회 실패 확인
cd-quality-gate-prod-workgroup Athena workgroup 조회 실패 확인
cd-quality-gate-prod-slack-approval API Gateway 조회 결과 없음
cd-quality-gate-prod/slack/webhook-url secret 보존 확인
cd-quality-gate/github/dispatch-token secret 보존 확인
```

검증:

```text
bash -n scripts/aws/destroy-terraform-stack.sh 통과
scripts/aws/destroy-terraform-stack.sh --help 통과
bash -n scripts/test-local.sh 통과
scripts/test-local.sh 통과
```

주의:

```text
scripts/aws/stop-after-work.sh는 EC2/RDS/ECS/EKS/ASG가 있는 다른 실습 리소스용으로 남아 있지만, 이 프로젝트의 기본 비용 정리는 scripts/aws/destroy-terraform-stack.sh를 사용한다.
prod destroy는 ALLOW_PROD=true 없이는 차단된다.
```

### 2026-06-12 15:28 - apply 전 1/4/5번 점검 및 Slack signing secret 보강

작업:

```text
AWS 리소스를 다시 올리지 않고 확인 가능한 항목 1, 4, 5를 파일 기준으로 점검했다.
Terraform apply/destroy 순서를 Lambda zip -> fmt/validate/plan/apply -> output 확인 -> destroy 순서로 문서화했다.
deployment-action-executor의 dispatch input과 rollback/dr/manual_fix/change workflow_dispatch input이 일치하는지 확인했다.
dr/manual_fix/change에서 targetImageTag가 비어 있을 수 있으므로 executor가 currentImageTag로 fallback하도록 보강했다.
Slack signing secret은 Terraform variable 원문 주입 대신 AWS Secrets Manager ARN을 우선 사용하도록 slack-approval-handler와 Terraform을 보강했다.
apply 전 체크리스트 문서를 추가하고 README/docs index에 연결했다.
```

추가 파일:

```text
docs/20-implementation/28-pre-apply-verification-checklist.md
```

수정 파일:

```text
README.md
docs/README.md
docs/20-implementation/README.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
docs/90-reference/13-repository-architecture.md
infra/terraform/iam.tf
infra/terraform/lambda.tf
infra/terraform/variables.tf
lambda/deployment-action-executor/app.py
lambda/slack-approval-handler/app.py
work-log.md
```

검증:

```text
terraform fmt -check 통과
terraform validate 통과
python3 -m py_compile Lambda handler 2개 통과
scripts/test-local.sh 통과
scripts/lambda/package-analysis-orchestrator.sh 통과
```

남은 확인:

```text
Slack App Interactivity Request URL은 Terraform apply 후 새 slack_interactivity_url output으로 등록해야 한다.
실제 GitHub repository에 대상 workflow가 존재하고 dispatch 가능한지는 apply 후 GitHub API smoke test로 확인한다.
EKS/Prometheus/backend-api-prod가 살아난 뒤에만 실제 E2E 테스트가 가능하다.
```

### 2026-06-12 16:49 - CD Quality Gate Control Center 대시보드 추가

작업:

```text
CD Quality Gate 운영 흐름을 한 화면에서 추적하는 dashboard/ 정적 운영 콘솔을 추가했다.
AWS 리소스가 꺼져 있어도 demo fixture로 Deployment Timeline, Quality Gate Health, Alert Coverage, AI Incident Analysis, Approval & Action, Infra & Cost 상태를 볼 수 있게 구성했다.
나중에 API Gateway/S3/GitHub Actions/Prometheus를 붙일 수 있도록 demo/live adapter 경계를 dashboard/src/data/loadDashboardData.js로 분리했다.
dashboard/dashboard-data.json을 두고 ?mode=live로 열면 live data를 읽도록 준비했다.
dashboard data contract를 JSON Schema로 문서화했다.
scripts/test-local.sh에 dashboard JavaScript syntax와 schema JSON 검증을 추가했다.
README와 repository architecture 문서에 dashboard 영역을 추가했다.
```

추가 파일:

```text
dashboard/README.md
dashboard/index.html
dashboard/src/main.js
dashboard/src/styles.css
dashboard/src/data/loadDashboardData.js
dashboard/src/data/sample-dashboard.js
dashboard/data-contracts/dashboard-data.schema.json
```

수정 파일:

```text
README.md
docs/90-reference/13-repository-architecture.md
scripts/test-local.sh
work-log.md
```

검증:

```text
node --check dashboard/src/main.js 통과
node --check dashboard/src/data/loadDashboardData.js 통과
node --check dashboard/src/data/sample-dashboard.js 통과
python3 -m json.tool dashboard/data-contracts/dashboard-data.schema.json 통과
scripts/test-local.sh 통과
```

실행:

```text
python3 -m http.server 5173 --directory dashboard
http://localhost:5173
http://localhost:5173?mode=live
```

### 2026-06-12 15:00 - Terraform 기반 AWS 리소스 생성 및 6개 체크리스트 테스트

작업:

```text
AWS login 프로필 ksw2 세션을 갱신했다.
Lambda zip 경로가 Terraform module 기준 build/를 바라보던 문제를 repo root build/ 기준으로 수정했다.
Terraform fmt/validate/plan/apply를 실행해 cd-quality-gate-prod AWS 리소스를 생성했다.
Slack webhook secret은 기존 AWS Secrets Manager secret을 Terraform state로 import한 뒤 태그를 Terraform 기준으로 관리하도록 정리했다.
Bedrock Claude 3 Haiku smoke invoke를 실행해 모델 접근과 invoke 권한을 확인했다.
stop-after-work.sh를 cd-quality-gate/prod 태그 기준 dry-run 및 execute로 실행해 gympt-ops 리소스가 대상에 잡히지 않음을 확인했다.
```

생성/확인 리소스:

```text
EventBridge bus: cd-quality-gate-prod-bus
EventBridge rules: cd-quality-gate-prod-deployment-failed, cd-quality-gate-prod-deployment-action-approved
Lambda: cd-quality-gate-prod-analysis-orchestrator
Lambda: cd-quality-gate-prod-slack-approval-handler
Lambda: cd-quality-gate-prod-deployment-action-executor
S3: cd-quality-gate-prod-results
Athena database: cd_quality_gate_prod_logs
Athena workgroup: cd-quality-gate-prod-workgroup
API Gateway: cd-quality-gate-prod-slack-approval
Slack interactivity URL: https://i9q80h811i.execute-api.ap-northeast-2.amazonaws.com/slack/interactions
```

수정 파일:

```text
infra/terraform/lambda.tf
.gitignore
work-log.md
```

검증:

```text
scripts/lambda/package-analysis-orchestrator.sh 통과
scripts/test-local.sh 통과
terraform fmt -check 통과
terraform validate 통과
terraform plan 통과
terraform apply 통과
aws events describe-event-bus 확인
aws lambda get-function 3개 Active 확인
aws s3api get-bucket-tagging 확인: Project=cd-quality-gate, Environment=prod
aws apigatewayv2 get-apis 확인
aws athena get-work-group 확인
aws bedrock-runtime invoke-model 확인: ok
scripts/aws/stop-after-work.sh dry-run/execute 확인: EC2/RDS/ECS/EKS/ASG 매칭 0개
```

주의:

```text
현재 생성된 AWS 리소스는 대부분 serverless 관리 리소스라 stop-after-work.sh로 끌 대상이 없다.
stop-after-work.sh는 삭제 스크립트가 아니며 EC2/RDS/ECS/EKS/ASG만 중지 또는 scale down한다.
완전 삭제가 필요하면 이 Terraform stack 기준으로만 terraform destroy를 사용해야 한다.
```

### 2026-06-12 10:12 - Amazon Bedrock AI 분석 연결

작업:

```text
analysis-orchestrator Lambda에 Amazon Bedrock Runtime 호출 adapter를 추가했다.
운영 기본값은 BEDROCK_ENABLED=true로 두고, Bedrock 호출 실패/비활성/boto3 미사용 환경에서는 기존 ai-agent rule analyzer로 fallback하도록 구성했다.
Bedrock 응답은 JSON으로 강제하고, 기존 Slack 2차 승인 메시지 포맷으로 변환한다.
Terraform에 Bedrock 관련 Lambda 환경변수와 bedrock:InvokeModel 권한을 추가했다.
Lambda 패키징 스크립트가 bedrock_agent.py를 analysis-orchestrator.zip에 포함하도록 수정했다.
```

추가 파일:

```text
lambda/analysis-orchestrator/bedrock_agent.py
```

수정 파일:

```text
lambda/analysis-orchestrator/app.py
scripts/lambda/package-analysis-orchestrator.sh
infra/terraform/variables.tf
infra/terraform/lambda.tf
infra/terraform/iam.tf
README.md
docs/20-implementation/18-lambda-analysis-orchestrator-design.md
docs/20-implementation/20-ai-agent-prompt-and-output-design.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
work-log.md
```

운영 전 확인:

```text
AWS Bedrock console에서 사용할 model access 활성화 필요
Lambda role에 bedrock:InvokeModel 권한 필요
기본 model id: anthropic.claude-3-haiku-20240307-v1:0
비용 제어가 필요하면 terraform var.bedrock_enabled=false로 fallback 분석만 사용 가능
```

검증:

```text
scripts/test-local.sh 통과
scripts/lambda/package-analysis-orchestrator.sh 통과
build/analysis-orchestrator.zip에 bedrock_agent.py 포함 확인
terraform -chdir=infra/terraform fmt -check 통과
GitHub workflow YAML parse 통과
```

### 2026-06-12 10:07 - Quality Gate 평가 범위 확장

작업:

```text
gympt-ops/gympt-gitops/platform/monitoring을 readonly reference로 확인했다.
backend PrometheusRule뿐 아니라 infrastructure PrometheusRule의 SQS, Kubernetes, GPU, Redis, Bedrock alert도 5분 Health Check Window 평가 대상에 포함했다.
evaluate-quality-gate.py가 backend-api service label만 엄격히 보는 구조에서 monitored namespace 기반 infrastructure alert도 평가할 수 있게 수정했다.
Slack 1차 알림 Grafana 링크를 api-latency 단일 dashboard에서 api-latency, eks-overview, jvm-metrics, gpu-metrics, redis-metrics, sqs-metrics 다중 dashboard로 확장했다.
```

참고한 readonly 파일:

```text
../gympt-ops/gympt-gitops/platform/monitoring/rules/prometheusrule-backend.yaml
../gympt-ops/gympt-gitops/platform/monitoring/rules/prometheusrule-infrastructure.yaml
../gympt-ops/gympt-gitops/platform/monitoring/prometheusrule-infrastructure.yaml
../gympt-ops/gympt-gitops/platform/monitoring/dashboard-api-latency.json
../gympt-ops/gympt-gitops/platform/monitoring/dashboard-eks-overview.json
../gympt-ops/gympt-gitops/platform/monitoring/dashboard-gpu-metrics.json
../gympt-ops/gympt-gitops/platform/monitoring/dashboard-jvm-metrics.json
../gympt-ops/gympt-gitops/platform/monitoring/dashboard-redis-metrics.json
../gympt-ops/gympt-gitops/platform/monitoring/dashboard-sqs-metrics.json
```

수정 파일:

```text
.github/workflows/quality-gate.yml
scripts/quality-gate/evaluate-quality-gate.py
scripts/quality-gate/run-health-check-window.sh
scripts/quality-gate/build-grafana-links.py
scripts/quality-gate/send-slack-first-alert.py
config/quality-gate/alert-mapping.yaml
config/quality-gate/grafana-dashboards.yaml
tests/fixtures/prometheus-alerts.firing.json
scripts/test-local.sh
README.md
docs/10-architecture/07-quality-gate-rules.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
work-log.md
```

검증:

```text
scripts/test-local.sh 통과
firing fixture에서 BackendHighErrorRate, BackendHighLatency, BackendDBPoolExhaustion, SQSMessageAge, RedisConnectionError, GPUMemoryHigh 총 6개 alert matched 확인
grafana-links.json에 api-latency, eks-overview, jvm-metrics, gpu-metrics, redis-metrics, sqs-metrics 포함 확인
```

### 2026-06-11 17:18 - Runtime flow 대조 및 누락 보정

작업:

```text
Quality Gate 이후 EventBridge, Lambda, AI Agent, Slack 승인, action executor 흐름을 실제 파일 기준으로 대조했다.
analysis-orchestrator Lambda가 Slack 2차 알림 webhook을 읽지 못하던 문제를 보정했다.
DeploymentFailed 이벤트와 Athena summary에 rollbackImageTag, Grafana/Prometheus/Argo CD 링크가 이어지도록 보강했다.
승인 이벤트 문서가 과거 fallback 흐름만 설명하던 부분을 Slack 버튼 -> API Gateway -> EventBridge -> action executor 자동 실행 흐름으로 정정했다.
```

수정 파일:

```text
lambda/analysis-orchestrator/app.py
scripts/quality-gate/publish-eventbridge-event.sh
infra/terraform/lambda.tf
infra/terraform/iam.tf
docs/20-implementation/08-events-and-slack-messages.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
work-log.md
```

주의:

```text
자동 rollback은 targetImageTag가 필요하다.
기존 app 배포 workflow가 이전 정상 image tag를 ROLLBACK_IMAGE_TAG로 넘기거나 별도 배포 이력 저장소에서 조회해야 완전히 자동 실행된다.
```

검증:

```text
bash -n scripts/quality-gate/*.sh scripts/cd/*.sh scripts/aws/*.sh scripts/runbooks/*.sh 통과
terraform -chdir=infra/terraform fmt 적용 및 fmt -check 통과
GitHub workflow YAML parse 통과
scripts/test-local.sh 통과
deployment-failed-event.json에 rollbackImageTag, argocdUrl, grafanaLinks, prometheusLinks 필드 포함 확인
```

### 2026-06-11 17:10 - Quality Gate 5분 Health Check Window 반영

작업:

```text
quality-gate.yml이 Prometheus를 단발 조회하던 구조를 5분 Health Check Window 구조로 변경했다.
run-health-check-window.sh를 추가해 기본 300초 동안 60초 간격으로 Prometheus alert/metric을 조회하고 sample별 결과를 집계한다.
로컬 테스트에서는 HEALTH_CHECK_WINDOW_SECONDS=0으로 빠르게 window 동작을 검증하도록 추가했다.
README와 runtime flow 문서에 5분 Health Check Window 기준을 반영했다.
```

추가 파일:

```text
scripts/quality-gate/run-health-check-window.sh
```

수정 파일:

```text
.github/workflows/quality-gate.yml
scripts/test-local.sh
README.md
docs/20-implementation/14-implementation-file-architecture.md
docs/20-implementation/15-github-actions-workflow-design.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
work-log.md
```

검증:

```text
HEALTH_CHECK_WINDOW_SECONDS=1 HEALTH_CHECK_INTERVAL_SECONDS=1 run-health-check-window.sh 통과
scripts/test-local.sh 통과
```

### 2026-06-11 16:32 - draw.io 기준 누락/불일치 점검

작업:

```text
cd-quality-gate-ai-incident-analysis.drawio의 주요 노드와 현재 구현 파일을 대조했다.
Bedrock은 실제 구현되어 있지 않고 현재 ai-agent/runbook reasoning 구조임을 확인했다.
rollback 문서에 남아 있던 직접 GitOps rollback/Quality Gate 재검증 책임 표현을 기존 GitOps/gympt-ops workflow 책임으로 정정했다.
```

남은 확인 항목:

```text
Athena가 읽을 central logs S3/Glue external table은 실제 gympt-ops 로그 저장소와 연결 확인 필요
Slack approval/API Gateway/action executor는 구현됐지만 draw.io에는 아직 별도 박스로 반영되지 않음
DR 실제 전환 명령은 dr-failover.yml에 아직 연결 필요
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
### 2026-06-16 14:47 - DR/manual fix/change 승인 흐름 정리

작업:

```text
rollback은 승인 후 GitOps image tag를 직접 되돌리는 자동 조치로 유지했다.
DR/manual fix/change는 승인 후 바로 외부 workflow나 app deploy workflow를 호출하지 않도록 정리했다.
DR/manual fix/change는 요청 기록 JSON, artifact, GitHub issue 생성까지만 수행하도록 변경했다.
Lambda executor가 넘기는 app_repo/app_workflow/app_ref input과의 호환성은 유지했다.
README와 세부 흐름 문서, pre-apply checklist, final checklist에 action별 자동화 수준을 반영했다.
```

수정 파일:

```text
.github/workflows/dr-failover.yml
.github/workflows/manual-fix.yml
.github/workflows/change-apply.yml
README.md
docs/20-implementation/28-pre-apply-verification-checklist.md
docs/20-implementation/30-final-status-and-user-checklist.md
docs/20-implementation/31-gympt-app-to-gitops-to-quality-gate-flow.md
work-log.md
```

현재 기준:

```text
rollback: 승인 후 자동 GitOps tag rollback
dr: 승인 후 DR review issue/artifact 생성
manual_fix: 승인 후 manual fix issue/artifact 생성
change: 승인 후 change review issue/artifact 생성
```

### 2026-06-16 14:58 - Dashboard backend/DB 연결 표시 및 실행 확인

작업:

```text
dashboard backend 서버를 5174 포트로 실행했다.
기존 5173 포트는 이미 사용 중이어서 DASHBOARD_PORT=5174로 띄웠다.
dashboard 서버에 /api/status endpoint를 추가했다.
dashboard 화면 상단에 Backend API, Action DB, Terraform Adapter 연결 상태 패널을 추가했다.
Action DB는 현재 dashboard/runtime/actions.json 파일 저장소를 사용한다.
브라우저에서 http://localhost:5174 URL을 열었다.
```

수정 파일:

```text
dashboard/server.mjs
dashboard/src/main.js
dashboard/src/styles.css
work-log.md
```

검증:

```text
GET /api/status 정상 응답
GET /api/dashboard 정상 응답
GET / 정상 응답
Backend API status: connected
Action DB status: connected
Terraform Adapter status: connected
```

### 2026-06-16 15:13 - DR/manual fix/change runbook action 자동화

작업:

```text
manual_fix/change를 구체 runbook action으로 세분화했다.
Bedrock prompt와 local analyzer가 rollback/dr/restart_deployment/scale_replicas/increase_memory/increase_hpa/open_fix_issue/open_change_pr/observe 중 하나를 추천하도록 변경했다.
Slack 승인 action value와 deployment-action-executor가 새 action type을 dispatch할 수 있게 확장했다.
change-apply.yml이 restart_deployment, scale_replicas, increase_memory, increase_hpa를 GitOps values patch로 자동 실행하도록 변경했다.
dr-failover.yml은 DR_VALUES_FILE/DR_YAML_PATH/DR_TARGET_VALUE가 설정된 경우 GitOps failover patch를 실행하고, 없으면 DR issue/artifact로 멈추게 했다.
dashboard action 목록에 세부 runbook action을 반영했다.
깨진 dashboard/runtime/actions.json을 복구하고, dashboard backend가 손상된 local DB를 만나도 죽지 않도록 방어 로직을 추가했다.
```

추가 파일:

```text
scripts/cd/update-gitops-yaml-value.sh
```

수정 파일:

```text
.github/workflows/approved-action.yml
.github/workflows/change-apply.yml
.github/workflows/dr-failover.yml
.github/workflows/manual-fix.yml
ai-agent/app/analyzer.py
dashboard/server.mjs
dashboard/src/data/sample-dashboard.js
lambda/analysis-orchestrator/bedrock_agent.py
lambda/deployment-action-executor/app.py
schemas/ai-agent/ai-recommendation.schema.json
schemas/eventbridge/deployment-action-approved.schema.json
scripts/quality-gate/publish-approved-action-event.sh
README.md
docs/20-implementation/31-gympt-app-to-gitops-to-quality-gate-flow.md
work-log.md
```

검증:

```text
GitHub Actions YAML parse 통과
python3 -m compileall ai-agent lambda 통과
scripts/test-local.sh 통과
scripts/lambda/package-analysis-orchestrator.sh 통과
update-gitops-yaml-value.sh dry-run 통과
dashboard /api/status 통과
dashboard /api/actions increase_memory 기록 통과
pytest는 현재 환경에 설치되어 있지 않아 실행하지 못함
```
