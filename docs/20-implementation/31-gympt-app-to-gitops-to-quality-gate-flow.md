# DOC-31. GymPT App to GitOps to Quality Gate Flow

이 문서는 `gympt-app -> gympt-gitops -> cd-quality-gate-architecture`가 어떻게 연결되는지 처음부터 끝까지 설명한다.

중요한 전제는 아래다.

```text
gympt-app:
  실제 서비스 코드, 빌드, 이미지 생성, 기존 배포 시작점

gympt-gitops:
  EKS에 배포할 Kubernetes desired state 저장소

cd-quality-gate-architecture:
  기존 배포가 끝난 뒤 배포가 진짜 안전한지 검증하고,
  실패하면 Slack 알림, AI 분석, 승인 기반 rollback/fix/change를 실행하는 개인 파트
```

`gympt-ops` 폴더는 참고용이다.  
이 프로젝트는 `gympt-ops` 파일을 직접 수정하지 않고, 기존 서비스 배포 흐름 뒤에 Quality Gate를 붙인다.

---

## 1. 전체 원칙

CI/CD는 역할을 분리한다.

```text
GitHub Actions
  -> 소스 코드 빌드
  -> 테스트
  -> Docker image 생성
  -> ECR push
  -> GitOps values image tag 수정

GitOps Repository
  -> Kubernetes/Helm 배포 선언 저장
  -> 어떤 image tag를 EKS에 배포할지 Git으로 기록

Argo CD
  -> GitOps repo를 감시
  -> Git 상태와 EKS 상태를 동기화

CD Quality Gate
  -> 배포 후 rollout 확인
  -> Prometheus 기준 5분 health check
  -> Slack 알림
  -> 실패 시 EventBridge/Lambda/Bedrock 분석
  -> 승인 기반 rollback/fix/change 실행

Terraform
  -> cd-quality-gate가 쓰는 AWS 리소스 생성/삭제
```

이렇게 나누는 이유:

```text
빌드와 배포 선언은 기존 서비스 책임이다.
배포 후 품질 검증과 장애 분석은 개인 프로젝트 책임이다.
서로 책임을 나누면 기존 gympt-app 배포를 깨지 않고 뒤에 안전장치를 붙일 수 있다.
```

---

## 2. 왜 gympt-app을 직접 수정하지 않는가

이번 연결 방식은 `gympt-app` workflow 파일을 수정하지 않는다.

대신 `gympt-app` repository settings에 GitHub Webhook을 추가한다.

```text
gympt-app backend workflow 완료
-> GitHub가 workflow_run webhook 전송
-> cd-quality-gate API Gateway 수신
-> GitHub webhook Lambda가 검증
-> cd-quality-gate quality-gate.yml workflow_dispatch 실행
```

이 방식을 쓰는 이유:

```text
1. gympt-app 코드와 workflow 파일을 건드리지 않는다.
2. ECR push보다 더 정확한 시점인 workflow_run completed를 기준으로 시작한다.
3. GitHub webhook secret으로 요청 위조를 막을 수 있다.
4. repo, workflow name, branch, conclusion을 Lambda에서 필터링할 수 있다.
5. cd-quality-gate 쪽 AWS/Terraform 리소스로 연결을 관리할 수 있다.
```

ECR image push 이벤트를 쓰지 않는 이유:

```text
ECR push는 "이미지가 올라갔다"는 뜻이다.
하지만 "서비스 배포가 끝났다"는 뜻은 아니다.

ECR push만 보면:
  GitOps values update가 됐는지
  Argo CD가 sync했는지
  EKS rollout이 끝났는지
  어떤 branch 배포인지
를 추가로 추적해야 한다.

그래서 실용성과 보안을 같이 보면 GitHub workflow_run webhook이 더 적합하다.
```

---

## 3. Repository별 역할

### 3.1 `gympt-app`

`gympt-app`은 실제 서비스 코드가 있는 repo다.

대표 역할:

```text
frontend 코드 빌드
backend-api 코드 빌드
Docker image 생성
ECR push
gympt-gitops values 파일 image tag 수정
```

읽는 파일:

```text
../gympt-ops/gympt-app/.github/workflows/backend-api-ci.yml
```

이 workflow가 하는 일:

```text
1. backend-api 코드 push 감지
2. Java 21 설정
3. Gradle build
4. Docker build
5. ECR login
6. ECR push
7. hj-3/gympt-gitops checkout
8. charts/backend-api/values-prod.yaml image.tag 수정
9. gympt-gitops main에 commit/push
```

중요:

```text
cd-quality-gate는 정상 배포 시 image tag를 만들지 않는다.
image tag는 gympt-app이 만든다.
```

image tag 전략:

```text
{github.run_number}-{GITHUB_SHA:0:7}
```

예:

```text
115-5c35fc1
```

Webhook Lambda도 이 규칙을 기준으로 새 image tag를 계산한다.

---

### 3.2 왜 frontend는 S3/CloudFront를 쓰는가

프론트엔드는 일반적으로 서버에서 계속 실행되는 프로세스가 아니다.  
React/Vite 같은 frontend는 빌드하면 정적 파일이 된다.

예:

```text
index.html
assets/*.js
assets/*.css
images/*
```

그래서 frontend 배포는 보통 아래처럼 간다.

```text
GitHub Actions
-> npm ci
-> npm run build
-> S3 bucket에 정적 파일 업로드
-> CloudFront cache invalidation
```

S3가 필요한 이유:

```text
정적 파일을 저장할 수 있다.
서버를 직접 띄우지 않아도 된다.
비용이 낮다.
AWS CloudFront origin으로 쓰기 쉽다.
```

CloudFront가 필요한 이유:

```text
사용자에게 가까운 edge location에서 정적 파일을 전달한다.
HTTPS 배포가 쉽다.
캐시를 사용할 수 있다.
배포 후 invalidation으로 최신 index.html을 보장할 수 있다.
```

캐시 전략:

```text
index.html:
  no-cache에 가깝게 관리
  최신 JS/CSS 파일명을 참조해야 하기 때문

JS/CSS assets:
  hash 기반 파일명이라 long cache 가능

CloudFront invalidation:
  index.html 또는 /* 무효화
```

이 frontend 배포는 Quality Gate의 backend-api 흐름과 직접 같지는 않지만, 같은 `gympt-app` 배포 책임 안에 있다.

---

### 3.3 `gympt-gitops`

`gympt-gitops`는 EKS에 배포할 상태를 Git으로 선언하는 repo다.

읽는 파일:

```text
../gympt-ops/gympt-gitops/charts/backend-api/values-prod.yaml
../gympt-ops/gympt-gitops/charts/backend-api/templates/deployment.yaml
../gympt-ops/gympt-gitops/charts/backend-api/templates/service.yaml
../gympt-ops/gympt-gitops/charts/backend-api/templates/servicemonitor.yaml
../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
```

핵심 values:

```yaml
image:
  repository: 337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api
  tag: "115-5c35fc1"
```

이 값의 의미:

```text
EKS에 backend-api를 어떤 Docker image로 띄울지 선언한다.
```

`gympt-app`이 이 값을 바꾸면:

```text
gympt-gitops main 변경
-> Argo CD가 변경 감지
-> Helm chart rendering
-> Kubernetes Deployment update
-> backend-api-prod pod rollout
```

---

### 3.4 왜 Helm Chart가 필요한가

Kubernetes 배포 파일은 보통 Deployment, Service, Ingress, HPA, ServiceMonitor 등 여러 파일로 나뉜다.

직접 YAML을 환경별로 복사하면 문제가 생긴다.

```text
dev/prod 파일이 서로 달라짐
같은 설정을 여러 곳에서 수정해야 함
image tag, replica, resources 같은 값 관리가 어려움
```

Helm은 Kubernetes manifest template 도구다.

Helm Chart 구조:

```text
charts/backend-api/
  Chart.yaml
  values.yaml
  values-prod.yaml
  templates/
    deployment.yaml
    service.yaml
    ingress.yaml
    hpa.yaml
    servicemonitor.yaml
```

Helm이 필요한 이유:

```text
공통 Kubernetes 구조는 templates에 둔다.
환경별 차이는 values-dev.yaml / values-prod.yaml로 나눈다.
image.tag만 바꿔도 전체 Deployment manifest가 새 image로 렌더링된다.
Argo CD가 Helm chart를 기준으로 EKS에 적용할 수 있다.
```

Quality Gate rollback/change도 Helm values를 바꾸는 방식으로 동작한다.

예:

```text
rollback:
  values-prod.yaml image.tag를 이전 tag로 되돌림

increase_memory:
  values-prod.yaml resources.requests.memory / limits.memory 수정

increase_hpa:
  values-prod.yaml autoscaling.maxReplicas 수정
```

이 방식이 중요한 이유:

```text
kubectl로 직접 고치면 GitOps desired state와 EKS live state가 어긋난다.
values를 Git에 commit하면 Argo CD가 Git 기준으로 동기화한다.
그래서 변경 이력과 rollback 이력이 Git에 남는다.
```

---

## 4. Argo CD 역할

Argo CD Application:

```text
../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
```

핵심 설정:

```text
Application name: backend-api-prod
source repo: https://github.com/hj-3/gympt-gitops.git
targetRevision: main
path: charts/backend-api
valueFiles: values-prod.yaml
destination namespace: gympt-prod
automated sync: enabled
selfHeal: enabled
```

Argo CD가 하는 일:

```text
1. gympt-gitops main branch 감시
2. charts/backend-api Helm chart 읽기
3. values-prod.yaml 적용
4. Kubernetes manifest 생성
5. EKS gympt-prod namespace에 적용
6. backend-api-prod Deployment rollout
```

Argo CD가 필요한 이유:

```text
Git을 배포 기준으로 삼을 수 있다.
누가 언제 어떤 image tag를 배포했는지 Git history로 추적할 수 있다.
rollback도 Git commit으로 처리할 수 있다.
EKS 상태가 Git과 달라지면 selfHeal로 되돌릴 수 있다.
```

---

## 5. cd-quality-gate 연결 방식

`gympt-app` 배포가 끝난 뒤 cd-quality-gate를 실행하는 연결점은 GitHub Webhook이다.

GitHub repo setting에서 추가할 webhook:

```text
Repository: hj-3/gympt-app
Payload URL: Terraform output github_webhook_url
Content type: application/json
Secret: AWS Secrets Manager에 저장한 GitHub webhook secret과 동일한 값
Event: Workflow runs
```

Terraform output:

```text
github_webhook_url
```

Terraform이 만드는 파일:

```text
infra/terraform/apigateway.tf
infra/terraform/lambda.tf
infra/terraform/iam.tf
infra/terraform/outputs.tf
```

Webhook을 받는 Lambda:

```text
lambda/github-webhook-handler/app.py
```

패키징:

```text
scripts/lambda/package-analysis-orchestrator.sh
-> build/github-webhook-handler.zip 생성
```

---

## 6. GitHub Webhook 상세 흐름

### Step 6.1 gympt-app backend workflow 완료

트리거:

```text
gympt-app backend-api-ci.yml workflow_run completed
```

GitHub가 보내는 payload 안에는 아래 정보가 있다.

```text
repository.full_name
workflow_run.name
workflow_run.conclusion
workflow_run.head_branch
workflow_run.run_number
workflow_run.head_sha
```

### Step 6.2 API Gateway가 Webhook 수신

실행 파일:

```text
infra/terraform/apigateway.tf
```

생성 리소스:

```text
aws_apigatewayv2_api.github_webhook
aws_apigatewayv2_route.github_webhook
aws_apigatewayv2_integration.github_webhook_handler
aws_apigatewayv2_stage.github_webhook
aws_lambda_permission.allow_apigateway_github_webhook
```

Endpoint:

```text
POST /github/webhooks
```

왜 API Gateway가 필요한가:

```text
GitHub Webhook은 인터넷에서 HTTPS endpoint로 요청을 보낸다.
Lambda는 직접 public HTTP endpoint가 아니다.
API Gateway가 public HTTPS endpoint 역할을 하고 Lambda로 요청을 넘긴다.
```

### Step 6.3 Lambda가 GitHub signature 검증

실행 파일:

```text
lambda/github-webhook-handler/app.py
```

검증하는 header:

```text
X-GitHub-Event
X-Hub-Signature-256
```

검증 방식:

```text
GitHub webhook secret + raw request body
-> HMAC SHA256 계산
-> X-Hub-Signature-256 값과 비교
```

왜 필요한가:

```text
API Gateway URL은 인터넷에 노출된다.
signature 검증이 없으면 아무나 quality-gate workflow를 실행시킬 수 있다.
그래서 webhook secret 검증은 필수다.
```

필요 secret:

```text
AWS Secrets Manager:
  cd-quality-gate/github/webhook-secret
```

Terraform variable:

```text
github_webhook_secret_arn
```

### Step 6.4 Lambda가 workflow_run 조건 필터링

`lambda/github-webhook-handler/app.py`가 확인하는 조건:

```text
X-GitHub-Event == workflow_run
payload.action == completed
repository.full_name == hj-3/gympt-app
workflow_run.name == Backend API CI/CD
workflow_run.head_branch == main
workflow_run.conclusion == success
workflow_run.event != pull_request
```

왜 필요한가:

```text
모든 workflow_run을 Quality Gate로 보내면 안 된다.
pull_request, 실패한 workflow, dev branch, 다른 workflow는 제외해야 한다.
운영 backend-api main 배포 성공 케이스만 Quality Gate를 실행해야 한다.
```

### Step 6.5 Lambda가 image tag 계산

gympt-app workflow image tag 규칙:

```text
${github.run_number}-${GITHUB_SHA:0:7}
```

Webhook Lambda 계산:

```text
workflow_run.run_number + "-" + workflow_run.head_sha[:7]
```

최종 image:

```text
337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:<tag>
```

예:

```text
337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:115-5c35fc1
```

### Step 6.6 Lambda가 cd-quality-gate workflow_dispatch 실행

dispatch 대상:

```text
repo: seungwankim364/g2mpt-cicd-ai-agent
workflow: quality-gate.yml
ref: main
```

실행 파일:

```text
lambda/github-webhook-handler/app.py
```

필요 secret:

```text
AWS Secrets Manager:
  cd-quality-gate/github/dispatch-token
```

왜 dispatch token이 필요한가:

```text
Lambda가 GitHub API를 호출해서 cd-quality-gate repo의 workflow를 실행해야 한다.
GitHub API workflow_dispatch 호출에는 권한이 있는 token이 필요하다.
```

전달하는 inputs:

```text
service=backend-api
environment=prod
namespace=gympt-prod
deployment=backend-api-prod
image_tag=<ECR image URI>
```

---

## 7. Quality Gate workflow 상세 흐름

실행 파일:

```text
.github/workflows/quality-gate.yml
```

왜 이 workflow가 필요한가:

```text
Argo CD sync 또는 GitHub Actions 성공만으로는 서비스가 건강한지 알 수 없다.
Kubernetes rollout과 Prometheus alert를 같이 봐야 배포 안정성을 판단할 수 있다.
```

runner:

```text
self-hosted, linux, eks
```

왜 self-hosted runner가 필요한가:

```text
Prometheus URL이 EKS 내부 주소다.
kubectl rollout 확인도 EKS 접근 권한이 필요하다.
GitHub-hosted runner는 내부 Kubernetes service 주소를 볼 수 없다.
```

### Step 7.1 cd-quality-gate repo checkout

실행:

```yaml
actions/checkout@v4
repository: seungwankim364/g2mpt-cicd-ai-agent
ref: main
```

왜 명시 checkout이 필요한가:

```text
workflow_call 또는 외부 dispatch 환경에서 caller repo가 checkout될 수 있다.
Quality Gate script는 cd-quality-gate repo 안에 있다.
그래서 repository를 명시해서 scripts/quality-gate/* 경로를 보장한다.
```

### Step 7.2 AWS credentials 설정

실행:

```text
aws-actions/configure-aws-credentials@v4
```

사용 secret:

```text
AWS_ROLE_ARN
```

왜 필요한가:

```text
Quality Gate 실패 시 EventBridge에 DeploymentFailed event를 발행해야 한다.
그 작업에는 events:PutEvents 권한이 필요하다.
```

### Step 7.3 Kubernetes rollout 확인

실행 파일:

```text
scripts/cd/check-k8s-rollout.sh
```

환경 변수:

```text
K8S_NAMESPACE=gympt-prod
K8S_DEPLOYMENT=backend-api-prod
EXPECTED_IMAGE=337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:<이번 배포 tag>
```

하는 일:

```text
1. backend-api-prod Deployment의 container image가 EXPECTED_IMAGE와 같아질 때까지 대기
2. kubectl rollout status deployment/backend-api-prod -n gympt-prod
3. kubectl get deploy backend-api-prod -n gympt-prod
4. kubectl get pods -l app=backend-api-prod -n gympt-prod
```

왜 image tag 확인을 먼저 하는가:

```text
gympt-app workflow가 성공했다는 것은 ECR push와 gympt-gitops values commit/push가 끝났다는 뜻이다.
하지만 Argo CD가 그 Git 변경을 EKS에 반영하는 데는 약간의 시간이 걸릴 수 있다.

이때 곧바로 kubectl rollout status만 실행하면,
아직 새 image가 적용되지 않은 이전 Deployment 상태를 보고 성공으로 판단할 수 있다.

그래서 Quality Gate는 먼저 Deployment spec의 container image가 이번 배포 image tag와 같아졌는지 확인한다.
그 다음에 rollout status를 본다.
이 순서가 있어야 "이전 배포가 건강한지"가 아니라 "이번 배포가 건강한지"를 검증할 수 있다.
```

실제 명령 기준:

```text
kubectl get deploy backend-api-prod -n gympt-prod -o jsonpath=...
kubectl rollout status deployment/backend-api-prod -n gympt-prod
kubectl get deploy backend-api-prod -n gympt-prod
kubectl get pods -l app=backend-api-prod -n gympt-prod
```

왜 먼저 rollout을 확인하는가:

```text
pod가 아직 뜨지 않았는데 Prometheus alert만 보면 원인을 잘못 판단할 수 있다.
먼저 Kubernetes가 이번 image tag로 새 Deployment를 정상 rollout했는지 확인해야 한다.
```

### Step 7.4 5분 Health Check Window

실행 파일:

```text
scripts/quality-gate/run-health-check-window.sh
```

내부에서 실행하는 파일:

```text
scripts/quality-gate/query-prometheus-alerts.sh
scripts/quality-gate/query-prometheus-metrics.sh
scripts/quality-gate/evaluate-quality-gate.py
```

설정:

```text
HEALTH_CHECK_WINDOW_SECONDS=300
HEALTH_CHECK_INTERVAL_SECONDS=60
```

왜 5분을 보는가:

```text
배포 직후에는 pod warm-up, connection 재생성, cache miss 때문에 일시적 흔들림이 있을 수 있다.
한 번만 보고 실패 처리하면 오탐이 생길 수 있다.
반대로 5분 동안 반복해서 firing alert가 보이면 배포 영향 가능성이 더 높다.
```

평가 alert:

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

이 alert들은 `gympt-gitops/platform/monitoring`의 PrometheusRule과 dashboard 기준을 참고해서 확장했다.

### Step 7.5 성공 시 Slack 완료 알림

실행 파일:

```text
scripts/quality-gate/send-slack-deploy-success.py
```

의미:

```text
GitHub Actions 성공
Argo CD 반영
Kubernetes rollout 성공
Prometheus 5분 health check 성공
```

즉, 단순히 이미지가 올라간 것이 아니라 배포 후 안정성까지 통과했다는 뜻이다.

### Step 7.6 실패 시 Slack 1차 알림

실행 파일:

```text
scripts/quality-gate/build-grafana-links.py
scripts/quality-gate/send-slack-first-alert.py
```

Slack 1차 알림에 포함되는 것:

```text
service
namespace
firing alerts
Grafana dashboard link
Prometheus alert link
Argo CD app link
GitHub Actions run link
```

왜 1차 알림이 필요한가:

```text
AI 분석은 Lambda/Athena/Bedrock 과정을 거치므로 시간이 더 걸릴 수 있다.
운영자는 먼저 "배포가 실패했다"는 사실과 dashboard 링크를 빨리 받아야 한다.
```

### Step 7.7 EventBridge DeploymentFailed 발행

실행 파일:

```text
scripts/quality-gate/publish-eventbridge-event.sh
```

발행 대상:

```text
event bus: cd-quality-gate-prod-bus
source: cd.quality-gate
detail-type: DeploymentFailed
```

왜 EventBridge를 쓰는가:

```text
GitHub Actions에서 AI 분석을 직접 길게 실행하지 않는다.
실패 이벤트를 AWS EventBridge로 넘기면 Lambda가 비동기로 분석을 이어갈 수 있다.
GitHub Actions, Slack, Lambda 책임을 분리할 수 있다.
```

---

## 8. AI 분석 흐름

EventBridge rule:

```text
infra/terraform/eventbridge.tf
```

Lambda:

```text
lambda/analysis-orchestrator/app.py
```

패키징:

```text
build/analysis-orchestrator.zip
```

하는 일:

```text
1. DeploymentFailed event 수신
2. alert와 deployment metadata 정리
3. Athena query 실행
4. S3 result bucket에 summary 저장
5. Bedrock으로 장애 원인 분석
6. Bedrock 실패 시 local ai-agent fallback
7. Slack 2차 분석/승인 메시지 전송
```

Bedrock이 필요한 이유:

```text
Prometheus alert만 보면 "무슨 문제가 발생했는지"는 알 수 있지만,
"rollback이 좋은지", "메모리를 늘릴지", "issue를 열어야 하는지" 판단은 더 어렵다.
Bedrock은 alert, Athena summary, runbook 정보를 같이 보고 원인 후보와 추천 조치를 만든다.
```

fallback이 필요한 이유:

```text
Bedrock 권한, quota, model 오류가 나도 Slack 분석 흐름이 완전히 멈추면 안 된다.
그래서 local rule-based ai-agent가 대체 분석을 수행한다.
```

---

## 9. Slack 승인 흐름

Slack 2차 알림에는 승인 버튼이 있다.

지원 action:

```text
rollback
restart_deployment
scale_replicas
increase_memory
increase_hpa
open_fix_issue
open_change_pr
```

`observe`는 승인 버튼을 만들지 않는다.

Slack interactivity endpoint:

```text
POST /slack/interactions
```

Terraform output:

```text
slack_interactivity_url
```

실행 파일:

```text
lambda/slack-approval-handler/app.py
```

하는 일:

```text
1. Slack signature 검증
2. button payload 파싱
3. DeploymentActionApproved event 생성
4. EventBridge cd-quality-gate-prod-bus로 발행
```

왜 Slack signature 검증이 필요한가:

```text
승인 버튼은 운영 조치를 실행한다.
요청이 진짜 Slack에서 온 것인지 검증해야 한다.
```

---

## 10. 승인 후 자동 실행

EventBridge rule:

```text
DeploymentActionApproved
```

Lambda:

```text
lambda/deployment-action-executor/app.py
```

역할:

```text
승인된 action type을 보고 GitHub workflow_dispatch를 실행한다.
```

mapping:

```text
rollback:
  .github/workflows/rollback.yml

manual_fix / open_fix_issue:
  .github/workflows/manual-fix.yml

change / restart_deployment / scale_replicas / increase_memory / increase_hpa / open_change_pr:
  .github/workflows/change-apply.yml
```

필요 secret:

```text
AWS Secrets Manager:
  cd-quality-gate/github/dispatch-token
```

---

## 11. Rollback 흐름

실행 파일:

```text
.github/workflows/rollback.yml
scripts/cd/update-gitops-image-tag.sh
```

순서:

```text
1. Slack에서 rollback 승인
2. Slack approval Lambda가 DeploymentActionApproved 발행
3. deployment-action-executor Lambda가 rollback.yml dispatch
4. rollback.yml이 target_image_tag 확인
5. scripts/cd/update-gitops-image-tag.sh 실행
6. hj-3/gympt-gitops clone
7. charts/backend-api/values-prod.yaml image.tag를 이전 tag로 수정
8. gympt-gitops main에 commit/push
9. Argo CD가 변경 감지
10. backend-api-prod가 이전 image tag로 sync
```

왜 gympt-app을 다시 빌드하지 않는가:

```text
rollback은 새 이미지를 만드는 작업이 아니다.
이미 ECR에 존재하는 이전 image tag로 desired state를 되돌리는 작업이다.
```

---

## 12. Fix/Change 흐름

실행 파일:

```text
.github/workflows/manual-fix.yml
.github/workflows/change-apply.yml
scripts/cd/update-gitops-yaml-value.sh
```

자동 GitOps patch action:

```text
restart_deployment:
  podAnnotations.cd-quality-gate/restartedAt 갱신

scale_replicas:
  autoscaling.minReplicas=2

increase_memory:
  resources.requests.memory=2Gi
  resources.limits.memory=3Gi

increase_hpa:
  autoscaling.maxReplicas=30
```

issue/action record action:

```text
open_fix_issue:
  manual-fix.yml이 issue/artifact 생성

open_change_pr:
  change-apply.yml이 issue/artifact 생성
```

왜 모든 fix를 자동 코드 수정하지 않는가:

```text
코드 버그, DB schema, 외부 dependency 문제는 자동으로 고치기 어렵다.
대신 AI가 원인과 증거를 정리하고 issue/change record를 남긴다.
운영자가 fix PR을 만들면 기존 gympt-app -> gympt-gitops -> Argo CD -> Quality Gate 흐름을 다시 탄다.
```

---

## 13. Dashboard 흐름

Dashboard는 운영자가 현재 CD 상태를 보는 화면이다.

Frontend:

```text
dashboard/index.html
dashboard/src/main.js
dashboard/src/data/loadDashboardData.js
dashboard/src/styles.css
```

Local backend:

```text
dashboard/server.mjs
```

AWS backend:

```text
lambda/dashboard-api/app.py
```

Terraform:

```text
infra/terraform/dashboard.tf
```

기본값:

```text
enable_dashboard=false
```

왜 기본값이 false인가:

```text
CloudFront, S3, API Gateway, Lambda, DynamoDB가 추가로 생성된다.
비용 관리를 위해 Slack 운영 검증 전에는 dashboard stack을 끈 상태로 둔다.
```

Dashboard를 AWS에 올릴 때:

```bash
terraform -chdir=infra/terraform plan -var='enable_dashboard=true'
```

Dashboard가 보여주는 것:

```text
deployment summary
timeline
health window result
alert groups
AI analysis summary
approval/action history
Terraform resource status
GitHub Actions latest workflow runs
Argo CD sync/health status
Prometheus current firing alerts
Grafana/Prometheus/Argo CD/GitHub Actions/Slack links
```

Live integration:

```text
Dashboard API Lambda는 GitHub Actions API, Argo CD API, Prometheus API를 직접 조회한다.

GitHub Actions:
  hj-3/gympt-app backend-api-ci.yml 최근 workflow run 상태 조회

Argo CD:
  backend-api-prod Application sync status / health status 조회

Prometheus:
  /api/v1/alerts 기준 firing alert 조회

Grafana:
  상세 분석 dashboard link 제공

Slack:
  #cd-deploy-alarm channel link/status 제공
  Slack message history 직접 조회는 하지 않는다.
```

현재 운영 조건:

```text
GitHub private repo 조회에는 github_token_secret_arn이 필요하다.
Argo CD API 조회에는 dashboard_argocd_token_secret_arn 또는 접근 가능한 인증 방식이 필요하다.
Prometheus 기본 URL은 Kubernetes 내부 service 주소이므로, Lambda에서 접근하려면 네트워크 경로가 필요하다.

토큰 또는 네트워크 접근이 없으면 dashboard 전체가 실패하지 않고,
해당 integration을 unavailable로 표시한다.
```

---

## 14. Terraform 리소스

Terraform root:

```text
infra/terraform
```

기본 생성 리소스:

```text
GitHub webhook API Gateway
GitHub webhook Lambda
Slack approval API Gateway
Slack approval Lambda
EventBridge bus/rules/targets
analysis-orchestrator Lambda
deployment-action-executor Lambda
IAM roles/policies
S3 result bucket
Athena database/workgroup
```

Dashboard 활성화 시 추가:

```text
S3 dashboard bucket
CloudFront distribution
Dashboard API Gateway
Dashboard Lambda
DynamoDB action table
S3 objects for dashboard frontend
```

중요 output:

```text
github_webhook_url
slack_interactivity_url
event_bus_name
result_bucket_name
athena_database_name
athena_workgroup_name
dashboard_cloudfront_url
dashboard_api_url
```

AWS CLI login을 Terraform에서 쓸 때:

```bash
eval "$(aws configure export-credentials --profile ksw2 --format env)"
terraform -chdir=infra/terraform plan
```

---

## 15. Secret 목록

GitHub repo secret:

```text
PROMETHEUS_URL
SLACK_WEBHOOK_URL
AWS_ROLE_ARN
GH_WORKFLOW_DISPATCH_TOKEN
```

AWS Secrets Manager:

```text
cd-quality-gate/github/dispatch-token
cd-quality-gate/github/webhook-secret
cd-quality-gate/slack/signing-secret
cd-quality-gate-prod/slack/webhook-url
```

각 secret 역할:

```text
dispatch-token:
  Lambda가 GitHub workflow_dispatch API를 호출할 때 사용

webhook-secret:
  GitHub webhook 요청의 HMAC signature 검증

slack/signing-secret:
  Slack interactive button 요청 검증

slack/webhook-url:
  Lambda가 Slack 2차 분석 알림을 보낼 때 사용
```

---

## 16. 최종 전체 흐름

```text
1. Developer가 gympt-app backend-api 코드 push
2. gympt-app backend-api-ci.yml 실행
3. Docker image build
4. ECR push
5. gympt-gitops values-prod.yaml image.tag 수정
6. gympt-gitops main commit/push
7. gympt-app backend-api-ci.yml workflow completed
8. GitHub workflow_run completed webhook 발생
9. API Gateway /github/webhooks 수신
10. github-webhook-handler Lambda signature 검증
11. repo/workflow/branch/conclusion 필터링
12. quality-gate.yml workflow_dispatch
13. self-hosted runner에서 backend-api-prod image tag가 이번 배포 image로 바뀔 때까지 대기
14. Argo CD가 gympt-gitops 변경을 감지하고 backend-api-prod sync
15. self-hosted runner에서 Kubernetes rollout 확인
16. Prometheus 5분 health check
17. 성공이면 Slack 배포 완료 알림
18. 실패면 Slack 1차 실패 알림
19. EventBridge DeploymentFailed 발행
20. analysis-orchestrator Lambda 실행
21. Athena + Bedrock/local ai-agent 분석
22. Slack 2차 분석/승인 알림
23. 운영자가 rollback/fix/change 승인
24. Slack approval Lambda가 DeploymentActionApproved 발행
25. deployment-action-executor Lambda가 GitHub workflow dispatch
26. rollback/change/manual-fix workflow 실행
27. GitOps 변경이 있으면 Argo CD sync
28. 다시 Quality Gate 검증 흐름으로 이어짐
```

---

## 17. 서비스 올린 뒤 live 검증 순서

```text
1. Terraform apply
2. output github_webhook_url 확인
3. hj-3/gympt-app repository settings에 webhook 추가
4. webhook secret을 AWS Secrets Manager 값과 동일하게 입력
5. Event는 Workflow runs 선택
6. backend-api main 배포 실행
7. GitHub webhook delivery 2xx 확인
8. cd-quality-gate quality-gate.yml workflow 실행 확인
9. self-hosted runner에서 rollout 확인
10. Prometheus 5분 health check 확인
11. Slack #cd-deploy-alarm 완료 또는 실패 알림 확인
12. 실패 케이스에서 Bedrock 분석 Slack 2차 알림 확인
13. 승인 버튼 클릭
14. rollback/change/manual-fix workflow dispatch 확인
15. GitOps commit 또는 issue/artifact 생성 확인
```
