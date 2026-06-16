# DOC-35. Final Status and User Checklist

이 문서는 현재 `cd-quality-gate-architecture`에서 확실히 끝난 것과 아직 사용자가 확인해야 하는 것을 한곳에 정리한다.

기준은 아래와 같다.

```text
완료:
  로컬 파일, fixture, dry-run, Terraform validate 기준으로 확인된 것

남음:
  AWS apply, Slack App, GitHub Actions, EKS, Prometheus, 실제 서비스가 올라와야 확인 가능한 것
```

`gympt-ops`는 read-only reference다. 이 문서는 `gympt-ops`를 수정하라는 문서가 아니다.

## 1. 이미 있는 관련 체크리스트

이미 아래 문서가 있다.

| 문서 | 역할 |
| --- | --- |
| `docs/20-implementation/28-pre-apply-verification-checklist.md` | Terraform apply 전 확인 |
| `docs/20-implementation/29-dashboard-control-center-checklist.md` | dashboard 구현/버튼/live 연결 확인 |
| `docs/20-implementation/26-runtime-file-role-and-architecture-flow.md` | 전체 아키텍처와 실제 파일 실행 순서 |
| `work-log.md` | 언제 어떤 파일을 추가/수정했는지 작업 이력 |

이 문서는 위 문서들을 읽기 전에 현재 상태를 빠르게 판단하기 위한 최종 요약 체크리스트다.

## 2. 확실히 끝난 것

### 2.1 문서와 아키텍처

```text
[x] root README 정리
[x] docs/00-overview 문서 정리
[x] docs/10-architecture 문서 정리
[x] docs/20-implementation 문서 정리
[x] docs/30-presentation 문서 정리
[x] docs/90-reference 문서 정리
[x] work-log.md 기록 방식 추가
[x] cd-quality-gate-ai-incident-analysis.drawio 추가
[x] Runtime File Role and Architecture Flow 문서 추가
[x] gympt-ops는 read-only reference라고 문서화
```

핵심 기준 파일:

```text
README.md
work-log.md
cd-quality-gate-ai-incident-analysis.drawio
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/28-pre-apply-verification-checklist.md
docs/20-implementation/29-dashboard-control-center-checklist.md
```

### 2.2 Quality Gate 로컬 흐름

```text
[x] GitHub Actions quality-gate workflow scaffold
[x] 기존 CD 이후 호출할 wrapper workflow scaffold
[x] Kubernetes rollout 확인 script
[x] Prometheus alert 조회 script
[x] Prometheus metric 조회 script
[x] 5분 Health Check Window script
[x] Quality Gate pass/fail 판단 script
[x] Grafana dashboard link 생성 script
[x] Slack 1차 실패 알림 payload 생성/전송 script
[x] Slack 배포 완료 알림 payload 생성/전송 script
[x] EventBridge DeploymentFailed payload 생성/전송 script
```

현재 판단 범위:

```text
BackendHighErrorRate
BackendHighLatency
BackendPodRestarting
BackendDBPoolExhaustion
BackendHighMemoryUsage
SQSQueueBacklog
SQSMessageAge
SQSDLQMessages
NodeHighCPUUsage
PodRestartFrequent
GPUHighUtilization
GPUMemoryHigh
RedisConnectionError
RedisHighMemory
RedisHighEvictionRate
BedrockHighErrorRate
BedrockThrottling
```

### 2.3 AI Incident Analysis

```text
[x] EventBridge 이후 Lambda Orchestrator scaffold
[x] Athena query template
[x] Athena SQL query
[x] Bedrock adapter
[x] ai-agent local fallback
[x] AI recommendation schema
[x] Slack 2차 분석 알림 payload 구조
[x] Lambda package script
```

핵심 파일:

```text
lambda/analysis-orchestrator/app.py
lambda/analysis-orchestrator/bedrock_agent.py
lambda/analysis-orchestrator/ai_agent_adapter.py
ai-agent/app/analyzer.py
ai-agent/app/slack_message_builder.py
athena/templates/backend-api.json
athena/queries/*.sql
scripts/lambda/package-analysis-orchestrator.sh
```

### 2.4 Slack 승인과 자동 action dispatch

```text
[x] Slack approval handler Lambda scaffold
[x] Slack signing secret ARN 연결 변수
[x] DeploymentActionApproved EventBridge event schema
[x] Deployment action executor Lambda scaffold
[x] rollback GitOps workflow dispatch scaffold
[x] DR workflow dispatch scaffold
[x] manual fix workflow dispatch scaffold
[x] change workflow dispatch scaffold
[x] GitHub dispatch token secret ARN 연결 변수
```

핵심 파일:

```text
lambda/slack-approval-handler/app.py
lambda/deployment-action-executor/app.py
.github/workflows/rollback.yml
.github/workflows/dr-failover.yml
.github/workflows/manual-fix.yml
.github/workflows/change-apply.yml
.github/workflows/approved-action.yml
schemas/eventbridge/deployment-action-approved.schema.json
```

### 2.5 Terraform과 비용 관리

```text
[x] EventBridge Terraform scaffold
[x] Lambda Terraform scaffold
[x] API Gateway Terraform scaffold
[x] S3 result bucket Terraform scaffold
[x] Athena Terraform scaffold
[x] IAM Terraform scaffold
[x] Terraform variable 정리
[x] Terraform output 정리
[x] Terraform destroy script 추가
[x] Secrets Manager secret은 destroy 대상에서 제외하는 방식 정리
```

확인된 상태:

```text
[x] terraform -chdir=infra/terraform validate 통과
[x] terraform state list 기준 현재 state는 비어 있음
```

주의:

```text
현재 AWS 리소스가 살아있다는 뜻이 아니다.
state가 비어 있으므로 현재는 apply 전 또는 destroy 완료 상태다.
```

### 2.6 Dashboard

```text
[x] dashboard 정적 UI 추가
[x] local backend server 추가
[x] GET /api/dashboard 추가
[x] GET /api/actions 추가
[x] POST /api/actions 추가
[x] POST /api/infra/apply-plan 추가
[x] POST /api/infra/destroy-plan 추가
[x] rollback/dr/manual_fix/change 기록 버튼 연결
[x] apply/destroy plan 버튼 연결
[x] dashboard data contract 추가
[x] demo fallback 추가
```

핵심 파일:

```text
dashboard/server.mjs
dashboard/index.html
dashboard/src/main.js
dashboard/src/styles.css
dashboard/src/data/loadDashboardData.js
dashboard/src/data/sample-dashboard.js
dashboard/data-contracts/dashboard-data.schema.json
```

현재 dashboard 버튼은 실제 AWS/GitHub 작업을 실행하지 않는다. 로컬에서는 안전하게 action record와 plan만 남긴다.

### 2.7 로컬 테스트

```text
[x] scripts/test-local.sh 통과
[x] Terraform validate 통과
[x] Quality Gate pass fixture 통과
[x] Quality Gate fail fixture 통과
[x] Slack payload dry-run 통과
[x] EventBridge payload dry-run 통과
[x] AI Agent/Lambda local 실행 통과
[x] dashboard JS/server/schema 검증 통과
```

## 3. 사용자가 이미 끝낸 입력값

현재 대화 기준으로 사용자가 직접 만든 값:

```text
[x] GitHub Secret: PROMETHEUS_URL
[x] GitHub Secret: SLACK_WEBHOOK_URL
[x] GitHub Secret: AWS_ROLE_ARN
[x] AWS Secrets Manager: Slack webhook URL secret
[x] AWS Secrets Manager: GitHub dispatch token secret
[x] AWS Secrets Manager: Slack signing secret
```

Terraform 변수에 들어간 ARN:

```text
github_token_secret_arn:
  arn:aws:secretsmanager:ap-northeast-2:337112169365:secret:cd-quality-gate/github/dispatch-token-g3xyfK

slack_signing_secret_arn:
  arn:aws:secretsmanager:ap-northeast-2:337112169365:secret:cd-quality-gate/slack/signing-secret-sYcbdA
```

## 4. 아직 못 끝낸 것

아래 항목은 로컬 파일만으로 완료 처리할 수 없다.

### 4.1 AWS stack 재생성

```text
[ ] Lambda zip 재생성
[ ] terraform plan 확인
[ ] terraform apply 실행
[ ] EventBridge bus 생성 확인
[ ] Lambda 3개 생성 확인
[ ] API Gateway 생성 확인
[ ] S3 result bucket 생성 확인
[ ] Athena database/workgroup 생성 확인
[ ] terraform output 확인
```

확인해야 할 output:

```text
event_bus_name
lambda_function_name
result_bucket_name
athena_database_name
athena_workgroup_name
slack_interactivity_url
```

### 4.2 Slack App 실제 연결

```text
[ ] terraform output의 slack_interactivity_url 복사
[ ] Slack App Interactivity Request URL에 입력
[ ] Slack App 저장
[ ] Slack 버튼 클릭 테스트
[ ] API Gateway access log 확인
[ ] slack-approval-handler Lambda log 확인
[ ] DeploymentActionApproved EventBridge event 확인
```

### 4.3 서비스 복구 후 live Quality Gate

서비스가 비용 때문에 내려가 있으면 아래 항목은 확인할 수 없다.

```text
[ ] EKS node 복구
[ ] self-hosted runner 복구
[ ] Prometheus 복구
[ ] Grafana 접근 확인
[ ] backend-api-prod deployment 복구
[ ] Argo CD backend-api-prod sync 상태 확인
[ ] GitHub Actions quality-gate workflow_dispatch 실행
[ ] 5분 Health Check Window 실제 실행
[ ] Slack #cd-deploy-alarm 배포 완료 알림 확인
[ ] 실패 fixture가 아니라 실제 Prometheus alert 기준 실패 알림 확인
```

### 4.4 End-to-End 실패 시나리오

```text
[ ] 배포 실패 상황 생성 또는 안전한 테스트 event 발행
[ ] Slack 1차 실패 알림 확인
[ ] EventBridge DeploymentFailed event 확인
[ ] analysis-orchestrator Lambda 실행 확인
[ ] Athena query execution 확인
[ ] Bedrock 분석 호출 확인
[ ] Slack 2차 AI 분석/승인 알림 확인
[ ] rollback 승인 버튼 클릭
[ ] deployment-action-executor Lambda 실행 확인
[ ] GitHub workflow dispatch 확인
[ ] app redeploy dispatch 확인
[ ] 재배포 후 Quality Gate 재실행 확인
[ ] 최종 Slack 배포 완료 알림 확인
```

### 4.5 원격 GitHub workflow 확인

현재 local workflow scaffold는 있다. 하지만 실제 dispatch 대상 repository에 workflow가 있어야 한다.

```text
[x] cd-quality-gate rollback workflow가 GitOps values 직접 수정 방식으로 변경됨
[x] cd-quality-gate AWS dispatch token이 cd-quality-gate rollback.yml workflow_dispatch 권한을 갖는지 확인
[x] cd-quality-gate GitHub Secret GH_WORKFLOW_DISPATCH_TOKEN 존재 확인
[x] 새 PAT가 hj-3/gympt-gitops push 권한을 갖는지 확인
[ ] DR target repository에 dr-failover workflow 존재 확인
[ ] gympt-app repository에 app deploy workflow 존재 확인
[ ] dispatch token에 workflow dispatch 권한 확인
[ ] repository owner/name/ref 값 확인
```

### 4.6 Dashboard live 연결

```text
[ ] dashboard-data.json 생성 script 추가
[ ] S3 result summary에서 dashboard data 생성
[ ] GitHub Actions API로 workflow status 조회
[ ] Prometheus API로 live alert/metric 조회
[ ] Terraform output 값을 dashboard에 반영
[ ] Slack approval action history와 dashboard action history 대조
[ ] demo fallback 없이 live mode 검증
```

### 4.7 실제 조치 자동화 수준 확인

현재 rollback/DR/change/manual_fix는 승인 후 dispatch 구조까지 있다.

남은 확인:

```text
[ ] rollback workflow가 실제 GitOps image tag를 이전 tag로 되돌리는지 확인
[ ] DR workflow가 실제 DR 전환을 수행하는지 확인
[ ] manual_fix workflow가 실제 조치 흐름과 연결되는지 확인
[ ] change workflow가 실제 승인된 변경 실행 흐름과 연결되는지 확인
```

## 5. 사용자가 해야 할 일

### 5.1 서비스가 내려가 있는 지금 할 수 있는 일

```text
[x] docs 최종 검토 기준 문서 추가
[x] README 문구 업데이트
[x] GitHub Secrets 이름 정리
[x] AWS Secrets Manager secret ARN 입력
[x] dispatch 대상 repository/workflow 이름 정리
[x] dashboard 화면 구성 추가
[x] rollback workflow를 cd-quality-gate 직접 GitOps push 방식으로 변경
[x] Lambda zip 재생성
[x] terraform fmt -check 통과
[x] terraform validate 통과
[x] AWS login 재인증
[x] terraform plan -out=tfplan 실행
[x] GitHub dispatch token 권한 교체
[ ] Slack App Interactivity 메뉴 위치 확인
[ ] draw.io 아키텍처 박스와 DOC-31 흐름 일치 여부 최종 검토
```

### 5.2 서비스 테스트 전 사전 작업 체크리스트

이 단계에서는 `terraform apply`를 실행하지 않는다.

```text
1. [x] Lambda zip 재생성
   command: scripts/lambda/package-analysis-orchestrator.sh

2. [x] Terraform fmt 확인
   command: terraform -chdir=infra/terraform fmt -check

3. [x] Terraform validate 확인
   command: terraform -chdir=infra/terraform validate

4. [x] cd-quality-gate rollback workflow YAML 확인
   file: .github/workflows/rollback.yml

5. [x] AWS login 재인증
   command: aws login

6. [x] Terraform plan 확인
   command: AWS_PROFILE=ksw2 terraform -chdir=infra/terraform plan -out=tfplan
   result: 28 to add, 0 to change, 0 to destroy

7. [x] plan 결과에서 생성 대상 확인
   check: Lambda, EventBridge, API Gateway, S3, Athena, IAM

8. [x] GitHub token 권한 수정
   AWS secret token: repo scope 확인, cd-quality-gate rollback.yml workflow_dispatch 권한 확인
   GitHub secret GH_WORKFLOW_DISPATCH_TOKEN: secret name 존재 확인
   PAT permission: hj-3/gympt-gitops push true 확인
```

중요:

```text
terraform apply는 서비스 테스트 전 사전 작업 범위에서 제외한다.
현재 plan은 완료되었고 `tfplan` 파일이 생성되었다.
```

### 5.3 AWS를 다시 올릴 때 해야 할 일

```text
[ ] scripts/lambda/package-analysis-orchestrator.sh 실행
[ ] terraform -chdir=infra/terraform init 실행
[ ] terraform -chdir=infra/terraform validate 실행
[ ] terraform -chdir=infra/terraform plan -out=tfplan 실행
[ ] terraform -chdir=infra/terraform apply tfplan 실행
[ ] terraform output 저장
[ ] Slack App Request URL 연결
[ ] Lambda log group 확인
[ ] EventBridge rule target 확인
```

### 5.4 서비스가 다시 올라온 뒤 해야 할 일

```text
[ ] EKS node 확인
[ ] self-hosted runner online 확인
[ ] Prometheus URL 접근 확인
[ ] Grafana dashboard 접근 확인
[ ] backend-api-prod rollout 확인
[ ] quality-gate workflow_dispatch 실행
[ ] 성공 case Slack 알림 확인
[ ] 실패 case Slack 1차 알림 확인
[ ] AI 분석 Slack 2차 알림 확인
[ ] Slack 승인 버튼 확인
[ ] 자동 rollback 또는 DR dispatch 확인
[ ] 재배포 후 최종 완료 알림 확인
```

### 5.5 퇴근 전 해야 할 일

```text
[ ] cd-quality-gate Terraform state에 생성된 리소스만 확인
[ ] destroy dry-run 실행
[ ] 삭제 대상이 gympt-ops 리소스를 포함하지 않는지 확인
[ ] ALLOW_PROD=true와 --execute로 destroy 실행
[ ] terraform state list가 비었는지 확인
[ ] AWS Console에서 Lambda/S3/EventBridge/API Gateway/Athena 잔여 리소스 확인
```

## 6. 다음 작업 우선순위

현재 기준 가장 현실적인 순서는 아래다.

```text
1. AWS stack apply
2. Slack Interactivity Request URL 연결
3. Slack 버튼 -> API Gateway -> Lambda -> EventBridge smoke test
4. 서비스 복구
5. Quality Gate 실제 5분 Health Check
6. 실패 시나리오 end-to-end
7. dashboard live data 연결
8. 퇴근 전 Terraform destroy 검증
```

## 7. 완료 판단 기준

이 프로젝트를 실제로 완료했다고 말하려면 아래가 모두 통과해야 한다.

```text
[ ] terraform apply로 cd-quality-gate AWS 리소스 생성
[ ] Slack 버튼이 실제 Lambda까지 도달
[ ] DeploymentFailed event가 analysis-orchestrator를 실행
[ ] Bedrock 분석 결과가 Slack 2차 알림으로 도착
[ ] rollback/DR/change/manual_fix 승인 시 GitHub workflow가 자동 dispatch
[ ] app redeploy 후 Quality Gate가 다시 실행
[ ] 성공 시 Slack 배포 완료 알림 도착
[ ] terraform destroy로 이 프로젝트 리소스만 삭제
[ ] gympt-ops 리소스가 삭제/변경되지 않음
```
