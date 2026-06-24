# DOC-37. Clone to Run Step by Step

이 문서는 누군가 이 Git repository를 처음 clone했을 때, `cd-quality-gate-architecture` 서비스를 어떤 순서로 검증하고 실행해야 하는지 설명한다.

핵심 원칙은 다음과 같다.

```text
1. clone 직후에는 AWS 리소스를 만들지 않는다.
2. 먼저 local test로 코드와 fixture 흐름을 검증한다.
3. Lambda zip을 만든 뒤 Terraform plan으로 생성 예정 리소스를 확인한다.
4. 실제 apply는 EKS, Prometheus, Slack, GitHub webhook 테스트 준비가 끝났을 때만 한다.
5. 테스트가 끝나면 Terraform destroy script로 이 프로젝트 리소스만 삭제한다.
```

`gympt-ops`와 그 안의 `gympt-gitops`는 실제 서비스 참고용이다. 이 repository를 실행하기 위해 `gympt-ops` 파일을 직접 수정하지 않는다.

---

# 1. 전체 실행 단계 요약

```text
Git clone
↓
필수 도구 확인
↓
문서 읽기
↓
local test 실행
↓
Lambda zip package 생성
↓
Terraform fmt / validate
↓
Terraform plan
↓
선택: Terraform apply
↓
GitHub webhook 등록
↓
Slack interactivity URL 등록
↓
서비스 복구 후 live Quality Gate 테스트
↓
Dashboard 확인
↓
비용 절감을 위해 Terraform destroy
```

---

# 2. 필요한 도구

clone한 사람이 로컬에서 검증하려면 아래 도구가 필요하다.

```text
git
bash
python3
node
npm
zip
terraform
aws cli
```

실제 EKS 연동 테스트까지 하려면 추가로 필요하다.

```text
kubectl
argocd cli
GitHub repository 권한
AWS 계정 권한
Slack App 관리 권한
```

부하 테스트 시연까지 하려면 선택적으로 필요하다.

```text
k6
```

---

# 3. Repository Clone

처음에는 repository를 clone하고 root로 이동한다.

```bash
git clone <cd-quality-gate-architecture-repo-url>
cd cd-quality-gate-architecture
```

왜 필요한가:

```text
이 repository에는 Quality Gate workflow, Prometheus 검증 script,
Slack/EventBridge/Lambda/Terraform/Dashboard 코드가 모두 들어 있다.
모든 명령은 repository root 기준으로 실행하도록 작성되어 있다.
```

---

# 4. 먼저 읽어야 하는 문서

처음 실행하는 사람은 아래 순서로 읽으면 된다.

```text
README.md
docs/20-implementation/30-final-status-and-user-checklist.md
docs/20-implementation/31-gympt-app-to-gitops-to-quality-gate-flow.md
docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
docs/20-implementation/27-github-secrets-and-runtime-values.md
docs/20-implementation/28-pre-apply-verification-checklist.md
```

각 문서의 역할은 다음과 같다.

| 문서 | 왜 읽는가 |
| --- | --- |
| `README.md` | 이 repository가 무엇을 하는지 전체 요약 |
| `30-final-status-and-user-checklist.md` | 현재 끝난 것과 서비스 복구 후 해야 할 일 |
| `31-gympt-app-to-gitops-to-quality-gate-flow.md` | `gympt-app -> gympt-gitops -> cd-quality-gate` 전체 연결 흐름 |
| `26-runtime-file-role-and-architecture-flow.md` | 어떤 `yml`, `sh`, `py` 파일이 어떤 단계에서 실행되는지 |
| `27-github-secrets-and-runtime-values.md` | GitHub Secrets, AWS Secrets Manager, runtime 값 |
| `28-pre-apply-verification-checklist.md` | Terraform apply 전에 확인할 체크리스트 |

---

# 5. Local Test 실행

clone 후 가장 먼저 실행할 검증은 local test다.

```bash
scripts/test-local.sh
```

이 script가 확인하는 것:

```text
Shell script syntax
Python compile
JSON fixture/schema 유효성
Prometheus normal fixture 기준 Quality Gate pass
Prometheus firing fixture 기준 Quality Gate fail
5분 health check script의 pass/fail 판단
Slack 1차 실패 알림 payload 생성
Slack 배포 완료 알림 payload 생성
EventBridge DeploymentFailed payload 생성
AI Agent local 분석 실행
Lambda analysis-orchestrator local 실행
GitHub webhook handler signature/filter 로직
Dashboard JavaScript syntax
Terraform destroy script help
```

언제 실행해야 하는가:

```text
1. clone 직후
2. script, lambda, workflow, dashboard 코드를 수정한 직후
3. commit 전
4. Terraform apply 전
```

왜 필요한가:

```text
AWS 리소스를 만들기 전에 로컬 fixture만으로 핵심 로직이 깨지지 않았는지 확인하기 위해서다.
이 단계가 실패하면 실제 AWS apply 후에도 Slack, EventBridge, Lambda, Dashboard 흐름에서 문제가 날 가능성이 높다.
```

주의:

```text
이 테스트는 실제 Prometheus, Slack, EventBridge, Bedrock을 호출하지 않는다.
fixture와 dry-run 중심으로 코드 흐름을 검증한다.
```

---

# 6. Lambda Zip Package 생성

Terraform은 Lambda 함수를 만들 때 `build/*.zip` 파일을 참조한다. fresh clone 상태에서는 `build` 디렉터리가 없을 수 있으므로 Terraform plan/apply 전에 zip을 만든다.

```bash
scripts/lambda/package-analysis-orchestrator.sh
```

생성되는 파일:

```text
build/analysis-orchestrator.zip
build/slack-approval-handler.zip
build/deployment-action-executor.zip
build/dashboard-api.zip
build/github-webhook-handler.zip
```

각 zip의 역할:

| Zip | 역할 |
| --- | --- |
| `analysis-orchestrator.zip` | EventBridge 실패 이벤트 이후 Athena/Bedrock/Slack 분석 수행 |
| `slack-approval-handler.zip` | Slack 승인 버튼 요청 수신 |
| `deployment-action-executor.zip` | 승인된 rollback/fix/change action을 GitHub workflow로 dispatch |
| `dashboard-api.zip` | Dashboard가 GitHub Actions, Argo CD, Prometheus 상태를 조회하는 API |
| `github-webhook-handler.zip` | `gympt-app` workflow 완료 webhook을 받아 Quality Gate workflow dispatch |

언제 실행해야 하는가:

```text
1. fresh clone 후 Terraform plan/apply 전
2. lambda/* 코드를 수정한 뒤
3. dashboard API 코드를 수정한 뒤
4. Slack approval 또는 GitHub webhook handler를 수정한 뒤
```

왜 필요한가:

```text
Terraform은 Lambda source 코드를 직접 배포하지 않고 zip artifact를 배포한다.
따라서 zip을 만들지 않으면 Lambda 파일이 없어서 Terraform plan/apply가 실패할 수 있다.
```

---

# 7. Terraform Format / Validate

Terraform 파일 문법과 provider 구성을 확인한다.

```bash
terraform -chdir=infra/terraform fmt -check
terraform -chdir=infra/terraform validate
```

언제 실행해야 하는가:

```text
1. Terraform 파일을 수정한 뒤
2. plan 실행 전
3. apply 실행 전
```

왜 필요한가:

```text
fmt는 Terraform 코드 스타일을 확인한다.
validate는 변수, resource, output, provider 구성이 문법적으로 맞는지 확인한다.
이 단계가 실패하면 plan/apply도 정상적으로 진행되지 않는다.
```

---

# 8. AWS Login 확인

Terraform plan/apply는 AWS API를 호출하므로 AWS 인증이 필요하다.

이 프로젝트에서 사용하던 profile 예시는 `ksw2`다.

```bash
aws sts get-caller-identity --profile ksw2
```

정상이라면 계정 ID와 ARN이 출력된다.

필요하면 현재 shell에 profile credential을 export한다.

```bash
eval "$(aws configure export-credentials --profile ksw2 --format env)"
export AWS_REGION=ap-northeast-2
export AWS_DEFAULT_REGION=ap-northeast-2
```

왜 필요한가:

```text
Terraform plan도 실제 AWS account의 IAM, Lambda, S3, EventBridge, API Gateway 상태를 조회한다.
로그인이 안 되어 있으면 plan 단계부터 실패한다.
```

---

# 9. Terraform Plan

기본 Quality Gate 리소스만 확인한다.

```bash
terraform -chdir=infra/terraform plan -var='environment=prod'
```

Dashboard까지 포함해서 확인하려면 `enable_dashboard=true`를 넣는다.

```bash
terraform -chdir=infra/terraform plan -var='environment=prod' -var='enable_dashboard=true'
```

이 단계에서 확인하는 것:

```text
생성될 Lambda
EventBridge bus/rule/target
API Gateway endpoint
S3 result bucket
Athena database/workgroup
IAM role/policy
Slack approval endpoint
GitHub webhook endpoint
선택: Dashboard S3/CloudFront/API/DynamoDB
```

언제 실행해야 하는가:

```text
1. apply 전에는 반드시 실행
2. Terraform 파일 수정 후
3. Lambda zip package 생성 후
4. 비용 발생 리소스를 만들기 전에
```

왜 필요한가:

```text
plan은 실제 생성/변경/삭제될 AWS 리소스를 미리 보여준다.
이 프로젝트는 gympt-ops와 같은 AWS 계정을 사용할 수 있으므로,
반드시 cd-quality-gate 리소스만 생성되는지 확인해야 한다.
```

주의:

```text
plan은 리소스를 만들지 않는다.
URL output도 실제 apply 전에는 확정되지 않는다.
API Gateway URL, CloudFront URL은 apply 후에 확인한다.
```

---

# 10. Terraform Apply

실제 AWS 리소스를 만들 준비가 되었을 때만 apply한다.

기본 Quality Gate 리소스:

```bash
terraform -chdir=infra/terraform apply -var='environment=prod'
```

Dashboard 포함:

```bash
terraform -chdir=infra/terraform apply -var='environment=prod' -var='enable_dashboard=true'
```

apply 후 확인할 output:

```bash
terraform -chdir=infra/terraform output github_webhook_url
terraform -chdir=infra/terraform output slack_interactivity_url
terraform -chdir=infra/terraform output dashboard_api_url
terraform -chdir=infra/terraform output dashboard_cloudfront_url
terraform -chdir=infra/terraform output event_bus_name
terraform -chdir=infra/terraform output result_bucket_name
```

각 output의 역할:

| Output | 어디에 쓰는가 |
| --- | --- |
| `github_webhook_url` | `gympt-app` GitHub Webhook Payload URL |
| `slack_interactivity_url` | Slack App Interactivity Request URL |
| `dashboard_api_url` | Dashboard frontend가 호출할 API |
| `dashboard_cloudfront_url` | 운영 Dashboard 접속 URL |
| `event_bus_name` | DeploymentFailed 이벤트가 발행되는 EventBridge bus |
| `result_bucket_name` | 분석 결과와 Athena 관련 결과 저장 |

---

# 11. GitHub Webhook 등록

`gympt-app`을 직접 수정하지 않고 Quality Gate를 연결하려면 GitHub Webhook을 등록한다.

등록 위치:

```text
gympt-app repository
-> Settings
-> Webhooks
-> Add webhook
```

값:

```text
Payload URL:
terraform output github_webhook_url 값

Content type:
application/json

Secret:
AWS Secrets Manager에 저장한 cd-quality-gate/github/webhook-secret 값

Event:
Workflow runs
```

왜 필요한가:

```text
gympt-app의 backend-api-ci.yml이 완료되면 GitHub가 workflow_run completed event를 보낸다.
github-webhook-handler Lambda는 이 event를 받아서 성공한 main branch 배포인지 확인하고,
cd-quality-gate-architecture의 quality-gate.yml을 workflow_dispatch로 실행한다.
```

주의:

```text
API Gateway URL은 destroy 후 다시 apply하면 바뀔 수 있다.
URL이 바뀌면 GitHub Webhook Payload URL도 다시 수정해야 한다.
```

---

# 12. Slack Interactivity 등록

Slack 승인 버튼을 사용하려면 Slack App에 interactivity URL을 등록한다.

등록 위치:

```text
Slack App
-> Interactivity & Shortcuts
-> Request URL
```

값:

```text
terraform output slack_interactivity_url 값
```

왜 필요한가:

```text
AI 분석 2차 알림에는 rollback/fix/change 승인 버튼이 포함된다.
사용자가 Slack에서 버튼을 누르면 Slack이 이 Request URL로 요청을 보낸다.
slack-approval-handler Lambda는 서명을 검증하고 승인 이벤트를 EventBridge에 발행한다.
deployment-action-executor Lambda는 승인된 action에 맞는 GitHub workflow를 자동 실행한다.
```

---

# 13. 서비스 복구 후 Live 테스트 준비

비용 때문에 서비스가 내려가 있었다면 live 테스트 전에 아래가 살아 있어야 한다.

```text
EKS node
self-hosted runner
backend-api-prod Deployment
Argo CD backend-api-prod Application
Prometheus
Grafana
Slack webhook
GitHub webhook
```

왜 필요한가:

```text
Quality Gate는 실제 배포 image tag가 EKS Deployment에 반영됐는지 확인한다.
그 다음 Prometheus alert/metric과 AWS CloudWatch Alarm을 5분 동안 확인한다.
EKS node나 Prometheus가 꺼져 있으면 live Quality Gate는 정상 판단을 할 수 없다.
CloudWatch alarm 조회도 AWS OIDC role이 `cloudwatch:DescribeAlarms`, `cloudwatch:GetMetricStatistics` 권한을 가져야 정상 동작한다.
```

---

# 14. 실제 배포 후 Quality Gate 흐름

서비스가 켜진 뒤 실제 흐름은 다음과 같다.

```text
gympt-app backend-api 코드 push
↓
gympt-app .github/workflows/backend-api-ci.yml 실행
↓
Docker image build
↓
ECR push
↓
gympt-gitops values-prod.yaml image.tag 수정
↓
Argo CD가 변경 감지
↓
EKS backend-api-prod rollout
↓
GitHub workflow_run completed webhook 발생
↓
cd-quality-gate github-webhook-handler Lambda 호출
↓
quality-gate.yml workflow_dispatch
↓
check-k8s-rollout.sh로 실제 image tag 반영 확인
↓
run-health-check-window.sh로 Prometheus + CloudWatch 5분 검증
↓
성공: Slack 배포 완료 알림
↓
실패: Slack 1차 알림 + EventBridge DeploymentFailed
↓
analysis-orchestrator Lambda
↓
Athena/S3/Bedrock 분석
↓
Slack 2차 분석 알림 및 rollback/fix/change 승인 요청
```

---

# 15. Dashboard 실행

로컬에서 Dashboard UI만 확인하려면 다음을 실행한다.

```bash
node dashboard/server.mjs
```

접속:

```text
http://localhost:5173
```

이 로컬 실행은 기본적으로 sample data 또는 local backend adapter를 확인하는 용도다.

AWS에 Dashboard까지 apply한 경우에는 아래 output으로 접속한다.

```bash
terraform -chdir=infra/terraform output dashboard_cloudfront_url
```

Dashboard에서 확인할 항목:

```text
최근 GitHub Actions 성공/실패
Argo CD sync/health 상태
Prometheus firing alert
CloudWatch ALARM 상태 리소스
Quality Gate 상태
Slack 승인 action 상태
rollback/fix/change 요청 상태
```

주의:

```text
Dashboard live API가 GitHub, Argo CD, Prometheus를 조회하려면 token secret과 network 접근성이 필요하다.
GitHub는 API token이 필요하고, Argo CD와 Prometheus는 Lambda가 접근 가능한 URL이어야 한다.
내부 cluster service URL만 넣으면 Lambda에서 직접 접근하지 못할 수 있다.
```

---

# 16. k6 부하 테스트 시연

발표나 시연에서 Prometheus alert를 일부러 만들고 싶다면 k6 부하 테스트를 사용할 수 있다.

예시 흐름:

```text
backend-api endpoint에 k6 load 발생
↓
latency 또는 error rate 증가
↓
PrometheusRule firing 확인
↓
Quality Gate fail 확인
↓
Slack 1차 알림 확인
↓
AI 분석 2차 알림 확인
↓
Dashboard에서 Prometheus firing alert 확인
```

주의:

```text
운영 prod에 강한 부하를 걸면 실제 서비스 장애가 날 수 있다.
발표용이면 dev/stage 또는 제한된 endpoint에서 낮은 RPS부터 테스트한다.
```

---

# 17. 비용 절감을 위한 삭제

테스트가 끝나면 이 프로젝트에서 Terraform으로 만든 리소스만 삭제한다.

먼저 dry-run으로 삭제 계획을 확인한다.

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
scripts/aws/destroy-terraform-stack.sh
```

실제로 삭제하려면 명시적으로 `ALLOW_PROD=true`와 `--execute`를 붙인다.

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
ALLOW_PROD=true \
scripts/aws/destroy-terraform-stack.sh --execute
```

Dashboard만 따로 삭제하려면 다음 script를 사용한다.

Dry-run:

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
scripts/aws/destroy-dashboard-stack.sh
```

실제 삭제:

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
ALLOW_PROD=true \
scripts/aws/destroy-dashboard-stack.sh --execute
```

왜 필요한가:

```text
이 프로젝트는 Lambda, API Gateway, EventBridge, S3, Athena, CloudFront 같은 AWS 리소스를 만든다.
테스트 후 계속 둘 필요가 없으면 Terraform destroy로 비용을 줄인다.
destroy script는 Terraform state 기준 cd-quality-gate 리소스만 삭제하도록 설계되어 있다.
```

주의:

```text
destroy 후 다시 apply하면 API Gateway URL과 CloudFront URL이 바뀔 수 있다.
그러면 GitHub Webhook URL, Slack Interactivity URL, Dashboard URL을 다시 확인해야 한다.
```

---

# 18. 자주 나는 문제

## Lambda zip 파일이 없다고 나올 때

원인:

```text
fresh clone 후 build/*.zip을 만들지 않았다.
```

해결:

```bash
scripts/lambda/package-analysis-orchestrator.sh
```

## Terraform plan이 AWS 인증 오류로 실패할 때

원인:

```text
AWS login/profile이 현재 shell에 잡혀 있지 않다.
```

해결:

```bash
aws sts get-caller-identity --profile ksw2
eval "$(aws configure export-credentials --profile ksw2 --format env)"
```

## GitHub Webhook delivery가 실패할 때

확인:

```text
Payload URL이 최신 github_webhook_url인지
Content type이 application/json인지
Secret 값이 AWS Secrets Manager 값과 같은지
Event가 Workflow runs인지
API Gateway/Lambda가 apply되어 있는지
```

## Quality Gate가 rollout에서 멈출 때

확인:

```text
EKS node가 살아 있는지
self-hosted runner가 살아 있는지
kubectl이 cluster에 접근 가능한지
Argo CD가 gympt-gitops 변경을 sync했는지
Deployment image tag가 이번 배포 tag로 바뀌었는지
```

## Rollback 승인 후 실행이 실패할 때

확인:

```text
Quality Gate 실패 시 이전 ReplicaSet image를 찾았는지
deployment-failed-event.json의 rollbackImageTag가 비어 있지 않은지
EKS Deployment revisionHistoryLimit이 이전 ReplicaSet을 보관하고 있는지
GH_WORKFLOW_DISPATCH_TOKEN GitHub Secret이 cd-quality-gate repo에 등록되어 있는지
해당 token이 hj-3/gympt-gitops contents write 권한을 갖는지
```

## Prometheus 조회가 실패할 때

확인:

```text
PROMETHEUS_URL 값이 실제 접근 가능한 URL인지
Prometheus service/pod가 살아 있는지
Lambda 또는 runner가 Prometheus에 network 접근 가능한지
```

## Dashboard에서 GitHub/Argo/Prometheus가 unavailable일 때

확인:

```text
GitHub token secret ARN
Argo CD token secret ARN
Argo CD URL
Prometheus URL
Lambda IAM secretsmanager:GetSecretValue 권한
Lambda에서 해당 URL에 접근 가능한 network 경로
```

---

# 19. 최소 실행 순서

로컬 검증만 할 때:

```bash
git clone <repo-url>
cd cd-quality-gate-architecture
scripts/test-local.sh
node dashboard/server.mjs
```

Terraform plan까지 할 때:

```bash
git clone <repo-url>
cd cd-quality-gate-architecture
scripts/test-local.sh
scripts/lambda/package-analysis-orchestrator.sh
terraform -chdir=infra/terraform fmt -check
terraform -chdir=infra/terraform validate
eval "$(aws configure export-credentials --profile ksw2 --format env)"
terraform -chdir=infra/terraform plan -var='environment=prod' -var='enable_dashboard=true'
```

실제 AWS 리소스까지 만들 때:

```bash
git clone <repo-url>
cd cd-quality-gate-architecture
scripts/test-local.sh
scripts/lambda/package-analysis-orchestrator.sh
terraform -chdir=infra/terraform fmt -check
terraform -chdir=infra/terraform validate
eval "$(aws configure export-credentials --profile ksw2 --format env)"
terraform -chdir=infra/terraform apply -var='environment=prod' -var='enable_dashboard=true'
terraform -chdir=infra/terraform output github_webhook_url
terraform -chdir=infra/terraform output slack_interactivity_url
terraform -chdir=infra/terraform output dashboard_cloudfront_url
```

테스트 후 삭제할 때:

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
scripts/aws/destroy-terraform-stack.sh

AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
ALLOW_PROD=true \
scripts/aws/destroy-terraform-stack.sh --execute
```

---

# 20. 최종 기준

이 repository를 clone한 사람이 아래까지 완료하면 사전 실행 준비가 끝난 것이다.

```text
scripts/test-local.sh 통과
Lambda zip package 생성 완료
terraform fmt -check 통과
terraform validate 통과
terraform plan 통과
GitHub webhook 등록 준비 완료
Slack interactivity 등록 준비 완료
Dashboard live 연결 값 준비 완료
서비스 복구 후 live Quality Gate 테스트 순서 이해
테스트 후 destroy 절차 이해
```

실제 운영 확인은 EKS node, Prometheus, Argo CD, backend-api-prod가 살아난 뒤 진행한다.
