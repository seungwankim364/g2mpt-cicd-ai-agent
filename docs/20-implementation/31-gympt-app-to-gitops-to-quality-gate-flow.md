# DOC-36. GymPT App to GitOps to Quality Gate Flow

이 문서는 `gympt-apps -> gympt-gitops -> cd-quality-gate-architecture` 흐름을 처음부터 끝까지 이해하기 위한 상세 실행 흐름이다.

목표는 아래 세 가지다.

```text
1. 어떤 repo가 어떤 책임을 갖는지 구분한다.
2. 배포 성공/실패/rollback 흐름에서 어떤 파일이 실행되는지 연결한다.
3. 사용자가 어느 지점에서 무엇을 확인해야 하는지 판단할 수 있게 한다.
```

## 1. 세 repo의 역할

### 1.1 gympt-apps

`gympt-apps`는 실제 서비스 코드를 빌드하고 이미지를 만드는 시작점이다.

책임:

```text
소스 코드 변경
테스트
Docker image build
ECR push
GitOps values image tag update
필요 시 cd-quality-gate workflow 호출
```

대표 흐름:

```text
backend-api 코드 변경
-> GitHub Actions 실행
-> test/build
-> Docker image 생성
-> ECR push
-> gympt-gitops values-prod.yaml image.tag 갱신
```

중요한 점:

```text
gympt-apps가 새 image tag를 만든다.
gympt-apps가 GitOps repo의 values-prod.yaml을 갱신한다.
cd-quality-gate는 새 이미지를 만들지 않는다.
```

### 1.2 gympt-gitops

`gympt-gitops`는 EKS에 어떤 상태를 배포할지 선언하는 repo다.

주요 파일:

```text
../gympt-ops/gympt-gitops/charts/backend-api/values-prod.yaml
../gympt-ops/gympt-gitops/charts/backend-api/templates/deployment.yaml
../gympt-ops/gympt-gitops/charts/backend-api/templates/service.yaml
../gympt-ops/gympt-gitops/charts/backend-api/templates/servicemonitor.yaml
../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
```

책임:

```text
Helm values 관리
Kubernetes manifest 렌더링 기준 제공
Argo CD Application source 제공
Prometheus/Grafana monitoring reference 제공
```

`values-prod.yaml`에서 핵심은 아래다.

```yaml
image:
  repository: 337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api
  tag: "..."
```

이 `image.tag`가 바뀌면 Argo CD가 변경을 감지하고 EKS에 반영한다.

### 1.3 cd-quality-gate-architecture

`cd-quality-gate-architecture`는 기존 배포가 끝난 뒤, 배포가 실제로 안전한지 검증하고 실패 시 분석/승인/조치를 연결하는 repo다.

책임:

```text
post-deploy rollout 확인
Prometheus/Grafana 기준 5분 health check
Slack 1차 실패 알림
EventBridge DeploymentFailed 이벤트 발행
Lambda + Athena + Bedrock AI 분석
Slack 2차 분석/승인 알림
승인된 rollback/DR/manual_fix/change 실행
dashboard/control center 제공
Terraform으로 AWS 리소스 관리
```

핵심 파일:

```text
.github/workflows/quality-gate.yml
.github/workflows/cd.yml
.github/workflows/rollback.yml
scripts/cd/check-k8s-rollout.sh
scripts/quality-gate/run-health-check-window.sh
scripts/quality-gate/query-prometheus-alerts.sh
scripts/quality-gate/query-prometheus-metrics.sh
scripts/quality-gate/evaluate-quality-gate.py
scripts/quality-gate/send-slack-first-alert.py
scripts/quality-gate/send-slack-deploy-success.py
scripts/quality-gate/publish-eventbridge-event.sh
lambda/analysis-orchestrator/app.py
lambda/deployment-action-executor/app.py
lambda/slack-approval-handler/app.py
infra/terraform/*.tf
```

## 2. 전체 정상 배포 흐름

정상 배포는 아래 순서로 흐른다.

```text
1. Developer가 gympt-apps backend-api 코드 push
2. gympt-apps GitHub Actions 실행
3. 테스트와 빌드 수행
4. Docker image 생성
5. ECR에 image push
6. gympt-gitops values-prod.yaml image.tag 변경
7. gympt-gitops main에 commit/push
8. Argo CD가 GitOps 변경 감지
9. Argo CD가 backend-api-prod를 EKS gympt-prod namespace에 sync
10. cd-quality-gate quality-gate.yml 실행
11. Kubernetes rollout 확인
12. Prometheus/Grafana 기준 5분 health check
13. 문제가 없으면 Slack #cd-deploy-alarm에 배포 완료 알림
```

## 3. Step-by-step 상세 흐름

### Step 1. gympt-apps 코드 push

시작점:

```text
repo: gympt-apps
actor: developer
event: push 또는 merge
target branch: develop/main 또는 운영 배포 branch
```

이 단계에서 일어나는 일:

```text
서비스 코드가 바뀐다.
GitHub Actions가 실행된다.
backend-api 기준으로 test/build/image build가 수행된다.
```

이 단계에서 `cd-quality-gate-architecture`는 아직 실행되지 않는다.

### Step 2. gympt-apps가 image를 만든다

일어나는 일:

```text
Gradle/Python/Node 등 서비스별 build
Docker build
ECR login
ECR push
```

결과:

```text
ECR repository에 새 image tag가 생긴다.
예: 337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:<new-tag>
```

중요한 판단:

```text
이 시점은 "이미지가 만들어진 것"이지 "서비스가 정상 배포된 것"이 아니다.
```

### Step 3. gympt-apps가 gympt-gitops values를 바꾼다

대상 파일:

```text
../gympt-ops/gympt-gitops/charts/backend-api/values-prod.yaml
```

변경 대상:

```yaml
image:
  tag: "<new-tag>"
```

의미:

```text
Kubernetes에 배포할 backend-api image tag를 Git으로 선언한다.
Argo CD는 이 Git 상태를 desired state로 본다.
```

주의:

```text
cd-quality-gate는 정상 배포 시작 시 이 값을 직접 바꾸지 않는다.
정상 배포의 values update는 기존 gympt-apps CI/CD 책임이다.
```

### Step 4. Argo CD가 gympt-gitops 변경을 감지한다

Argo CD Application 기준 파일:

```text
../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
```

핵심 설정:

```text
app: backend-api-prod
source repo: https://github.com/hj-3/gympt-gitops.git
path: charts/backend-api
valueFiles: values-prod.yaml
destination namespace: gympt-prod
```

Argo CD가 하는 일:

```text
gympt-gitops main branch 변경 감지
Helm chart 렌더링
Kubernetes manifest 적용
backend-api-prod Deployment update
Pod rollout 진행
```

중요한 판단:

```text
Argo CD sync가 끝났다는 것은 Kubernetes desired state 반영이 끝났다는 뜻이다.
하지만 서비스가 실제로 안정적인지는 아직 모른다.
```

## 4. cd-quality-gate 시작 지점

`cd-quality-gate-architecture`는 기존 배포 앞단을 대체하지 않는다.

시작 지점:

```text
Argo CD sync 이후
backend-api-prod rollout 이후
post-deploy 검증 단계
```

실행 workflow:

```text
.github/workflows/quality-gate.yml
```

선택 wrapper:

```text
.github/workflows/cd.yml
```

`quality-gate.yml` 입력:

```text
service: backend-api
environment: prod
namespace: gympt-prod
deployment: backend-api-prod
image_tag: 배포된 image tag
```

실행 runner:

```text
self-hosted, linux, eks
```

이 runner가 필요한 이유:

```text
EKS 내부 Kubernetes rollout 확인 필요
internal Prometheus service 접근 필요
```

## 5. Quality Gate 상세 실행

### Step 5.1 Kubernetes rollout 확인

실행 파일:

```text
scripts/cd/check-k8s-rollout.sh
```

환경 변수:

```text
K8S_NAMESPACE=gympt-prod
K8S_DEPLOYMENT=backend-api-prod
```

하는 일:

```text
kubectl rollout status deployment/backend-api-prod -n gympt-prod
```

판단:

```text
rollout 실패:
  Quality Gate 실패로 이어짐

rollout 성공:
  Prometheus 5분 health check로 넘어감
```

### Step 5.2 5분 Health Check Window 실행

실행 파일:

```text
scripts/quality-gate/run-health-check-window.sh
```

기본 설정:

```text
HEALTH_CHECK_WINDOW_SECONDS=300
HEALTH_CHECK_INTERVAL_SECONDS=60
```

의미:

```text
배포 직후 5분 동안 60초 간격으로 alert/metric을 반복 조회한다.
한 번만 보고 판단하지 않고, 배포 직후 안정성을 window로 본다.
```

내부에서 실행하는 파일:

```text
scripts/quality-gate/query-prometheus-alerts.sh
scripts/quality-gate/query-prometheus-metrics.sh
scripts/quality-gate/evaluate-quality-gate.py
```

결과 파일:

```text
prometheus-alerts-*.json
prometheus-metrics-*.json
quality-gate-result-*.json
quality-gate-window-result.json
quality-gate-result.json
```

### Step 5.3 Prometheus alert 조회

실행 파일:

```text
scripts/quality-gate/query-prometheus-alerts.sh
```

조회 대상:

```text
PROMETHEUS_URL
```

현재 기준:

```text
http://kube-prometheus-stack-prometheus.monitoring.svc:9090
```

조회하는 API:

```text
/api/v1/alerts
```

평가 namespace:

```text
gympt-prod
monitoring
posture-analysis
elasticache
```

### Step 5.4 Prometheus metric 조회

실행 파일:

```text
scripts/quality-gate/query-prometheus-metrics.sh
```

역할:

```text
배포 직후 metric snapshot을 남긴다.
Slack/Athena/AI 분석에서 참고할 수 있는 배포 직후 상태를 보존한다.
```

### Step 5.5 Quality Gate 판단

실행 파일:

```text
scripts/quality-gate/evaluate-quality-gate.py
```

판단 기준:

```text
firing alert 중에서
service/namespace/alert name이 현재 배포 대상과 연결되면 실패
```

현재 평가 alert:

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

판단 결과:

```text
pass:
  Slack 배포 완료 알림

fail:
  Slack 1차 실패 알림
  EventBridge DeploymentFailed 발행
  AI 분석으로 이동
```

## 6. Quality Gate 성공 흐름

성공 시 실행 파일:

```text
scripts/quality-gate/send-slack-deploy-success.py
```

Slack channel:

```text
#cd-deploy-alarm
```

메시지 의미:

```text
배포가 Kubernetes rollout만 통과한 것이 아니라
Prometheus 기준 5분 health check까지 통과했다는 뜻이다.
```

여기서 정상 배포 흐름은 종료된다.

## 7. Quality Gate 실패 흐름

실패 시 먼저 Grafana/Prometheus/Argo CD 링크를 만든다.

실행 파일:

```text
scripts/quality-gate/build-grafana-links.py
```

Slack 1차 실패 알림:

```text
scripts/quality-gate/send-slack-first-alert.py
```

Slack 1차 알림에 들어가는 것:

```text
service
environment
namespace
deployment
image tag
firing alerts
Grafana dashboard links
Prometheus link
Argo CD app link
GitHub Actions run link
```

이 알림은 "배포 실패를 빠르게 알리는 1차 알림"이다.

아직 AI 분석이 끝난 것은 아니다.

## 8. EventBridge로 실패 이벤트 발행

실행 파일:

```text
scripts/quality-gate/publish-eventbridge-event.sh
```

발행 대상:

```text
EventBridge bus: cd-quality-gate-prod-bus
detail-type: DeploymentFailed
source: cd.quality-gate
```

필요 권한:

```text
GitHub Actions OIDC 또는 AWS credential
events:PutEvents
```

이 이벤트가 AI 분석 Lambda를 시작한다.

## 9. Lambda Orchestrator 상세 흐름

트리거:

```text
EventBridge DeploymentFailed
```

실행 파일:

```text
lambda/analysis-orchestrator/app.py
```

Terraform 연결:

```text
infra/terraform/eventbridge.tf
infra/terraform/lambda.tf
infra/terraform/iam.tf
```

Orchestrator가 하는 일:

```text
1. DeploymentFailed event detail 읽기
2. service/environment/deployment/imageTag/alerts 추출
3. Athena query template 선택
4. Athena query 실행
5. Athena summary 생성 또는 fallback summary 생성
6. Bedrock AI 분석 호출
7. Bedrock 실패 시 local ai-agent fallback
8. Slack 2차 분석/승인 메시지 생성
9. Slack #cd-deploy-alarm에 전송
10. S3 result bucket에 분석 결과 저장
```

Athena template:

```text
athena/templates/backend-api.json
```

Athena query:

```text
athena/queries/alb-5xx-errors.sql
athena/queries/api-latency-top-paths.sql
athena/queries/application-error-patterns.sql
athena/queries/cloudfront-5xx-errors.sql
athena/queries/waf-blocked-requests.sql
```

Bedrock adapter:

```text
lambda/analysis-orchestrator/bedrock_agent.py
```

Fallback AI:

```text
ai-agent/app/analyzer.py
ai-agent/app/slack_message_builder.py
```

## 10. Slack 2차 분석/승인 흐름

Slack 2차 알림은 단순 실패 알림이 아니다.

포함 내용:

```text
AI 분석 요약
가능한 원인 후보
alert evidence
Athena log evidence
추천 조치
rollback / DR / change / manual fix 승인 버튼
```

승인 버튼을 누르면 Slack Interactivity가 API Gateway로 요청을 보낸다.

API Gateway:

```text
POST /slack/interactions
```

Terraform 파일:

```text
infra/terraform/apigateway.tf
```

Lambda:

```text
lambda/slack-approval-handler/app.py
```

Slack approval handler가 하는 일:

```text
1. Slack signature 검증
2. button payload 파싱
3. action type 확인
4. DeploymentActionApproved event 생성
5. EventBridge cd-quality-gate-prod-bus로 발행
```

필요 secret:

```text
AWS Secrets Manager:
cd-quality-gate/slack/signing-secret
```

## 11. 승인 이후 action executor

트리거:

```text
EventBridge DeploymentActionApproved
```

실행 파일:

```text
lambda/deployment-action-executor/app.py
```

역할:

```text
승인된 action type을 보고 GitHub workflow를 dispatch한다.
```

현재 action mapping:

```text
rollback:
  repo: seungwankim364/g2mpt-cicd-ai-agent
  workflow: rollback.yml

dr:
  repo: seungwankim364/g2mpt-cicd-ai-agent
  workflow: dr-failover.yml

manual_fix:
  repo: seungwankim364/g2mpt-cicd-ai-agent
  workflow: manual-fix.yml

change:
  repo: seungwankim364/g2mpt-cicd-ai-agent
  workflow: change-apply.yml
```

GitHub token 위치:

```text
AWS Secrets Manager:
cd-quality-gate/github/dispatch-token
```

중요:

```text
이 token은 cd-quality-gate repo workflow_dispatch 권한이 필요하다.
```

현재 Lambda는 SecretString이 JSON이어도 token 값을 추출할 수 있다.

지원하는 secret 형태:

```json
{
  "cd-quality-gate/github/dispatch-token": "ghp_..."
}
```

## 12. Rollback 상세 흐름

rollback 승인 시 실행되는 파일:

```text
.github/workflows/rollback.yml
```

이 workflow는 `gympt-apps`를 다시 빌드하지 않는다.

이유:

```text
rollback은 새 이미지를 만드는 것이 아니라
이미 존재하는 이전 image tag로 GitOps desired state를 되돌리는 작업이다.
```

실행 순서:

```text
1. rollback approval input 검증
2. target_image_tag 존재 확인
3. GH_WORKFLOW_DISPATCH_TOKEN 확인
4. rollback-request.json artifact 작성
5. scripts/cd/update-gitops-image-tag.sh 실행
6. hj-3/gympt-gitops clone
7. charts/backend-api/values-prod.yaml image.tag 수정
8. rollback commit 생성
9. gympt-gitops main에 push
10. Argo CD가 GitOps 변경 감지
11. backend-api-prod가 이전 image tag로 sync
```

실행 스크립트:

```text
scripts/cd/update-gitops-image-tag.sh
```

필요 GitHub Secret:

```text
GH_WORKFLOW_DISPATCH_TOKEN
```

필요 권한:

```text
hj-3/gympt-gitops contents read/write
```

주의:

```text
AWS Secrets Manager의 dispatch token과 GitHub Secret GH_WORKFLOW_DISPATCH_TOKEN은 역할이 다르다.

AWS Secrets Manager token:
  Lambda가 cd-quality-gate rollback.yml을 실행하기 위한 token

GitHub Secret GH_WORKFLOW_DISPATCH_TOKEN:
  rollback.yml이 gympt-gitops values-prod.yaml을 commit/push하기 위한 token
```

## 13. DR/manual fix/change 흐름

이제 `manual_fix/change`는 큰 버튼 하나가 아니라 실행 가능한 runbook action으로 쪼갠다.

```text
restart_deployment
  -> GitOps values podAnnotations.cd-quality-gate/restartedAt 갱신
  -> Argo CD sync
  -> pod template 변경으로 rollout restart 유도

scale_replicas
  -> GitOps values autoscaling.minReplicas=2 갱신
  -> Argo CD sync
  -> 최소 pod 수 증가

increase_memory
  -> GitOps values resources.requests.memory=2Gi
  -> GitOps values resources.limits.memory=3Gi
  -> Argo CD sync
  -> 메모리 여유 증가

increase_hpa
  -> GitOps values autoscaling.maxReplicas=30 갱신
  -> Argo CD sync
  -> HPA 상한 증가

open_fix_issue
  -> manual-fix.yml
  -> GitHub issue/artifact 생성
  -> gympt-app fix PR로 연결

open_change_pr
  -> change-apply.yml
  -> GitHub issue/artifact 생성
  -> GitOps/Terraform/app PR 중 하나로 연결
```

DR:

```text
.github/workflows/dr-failover.yml
```

현재 상태:

```text
DR_VALUES_FILE, DR_YAML_PATH, DR_TARGET_VALUE repository variable이 설정되어 있으면
scripts/cd/update-gitops-yaml-value.sh로 GitOps DR failover 값을 자동 갱신한다.
값이 없으면 DR review issue/artifact만 생성하고 멈춘다.
```

manual fix:

```text
.github/workflows/manual-fix.yml
```

현재 상태:

```text
manual_fix 또는 open_fix_issue action을 받는다.
승인 기록, artifact, GitHub issue를 생성한다.
코드 수정이 필요한 경우 gympt-app fix PR을 만들고
기존 gympt-app -> gympt-gitops -> Argo CD -> Quality Gate 흐름을 다시 탄다.
```

change:

```text
.github/workflows/change-apply.yml
```

현재 상태:

```text
change-apply.yml이 아래 action을 직접 처리한다.
restart_deployment, scale_replicas, increase_memory, increase_hpa는 GitOps values를 자동 patch한다.
change/open_change_pr은 승인 기록과 issue/artifact를 만든다.
```

## 14. Terraform이 만드는 AWS 연결

Terraform root:

```text
infra/terraform
```

현재 plan 결과:

```text
Plan: 28 to add, 0 to change, 0 to destroy
```

생성 대상:

```text
API Gateway Slack interactivity endpoint
EventBridge bus/rules/targets
Lambda analysis-orchestrator
Lambda slack-approval-handler
Lambda deployment-action-executor
IAM roles/policies
S3 result bucket
Athena database/workgroup
Secrets Manager slack webhook secret resource
```

중요 output:

```text
event_bus_name
lambda_function_name
result_bucket_name
athena_database_name
athena_workgroup_name
slack_interactivity_url
```

`slack_interactivity_url`은 apply 이후에만 확정된다.

## 15. 전체 흐름 한 장 요약

```text
gympt-apps
  push/merge
  -> build/test
  -> Docker build
  -> ECR push
  -> gympt-gitops values-prod.yaml image.tag update

gympt-gitops
  values-prod.yaml changed
  -> Argo CD detects change
  -> Helm render
  -> EKS gympt-prod/backend-api-prod sync

cd-quality-gate-architecture
  quality-gate.yml
  -> check-k8s-rollout.sh
  -> run-health-check-window.sh
  -> query-prometheus-alerts.sh
  -> query-prometheus-metrics.sh
  -> evaluate-quality-gate.py

if pass
  -> send-slack-deploy-success.py
  -> Slack #cd-deploy-alarm deploy complete

if fail
  -> build-grafana-links.py
  -> send-slack-first-alert.py
  -> publish-eventbridge-event.sh
  -> EventBridge DeploymentFailed
  -> analysis-orchestrator Lambda
  -> Athena + Bedrock/local ai-agent
  -> Slack #cd-deploy-alarm second analysis alert
  -> Slack approval button
  -> API Gateway /slack/interactions
  -> slack-approval-handler Lambda
  -> EventBridge DeploymentActionApproved
  -> deployment-action-executor Lambda
  -> rollback.yml / dr-failover.yml / manual-fix.yml / change-apply.yml

rollback path
  -> rollback.yml
  -> update-gitops-image-tag.sh
  -> gympt-gitops values-prod.yaml image.tag rollback commit
  -> Argo CD sync
  -> backend-api-prod rollback deployment
```

## 16. 사용자가 흐름을 확인할 때 읽는 순서

처음부터 끝까지 이해하려면 아래 순서로 보면 된다.

```text
1. README.md
2. docs/20-implementation/31-gympt-app-to-gitops-to-quality-gate-flow.md
3. docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
4. docs/20-implementation/27-github-secrets-and-runtime-values.md
5. docs/20-implementation/25-rollback-workflow-design.md
6. docs/20-implementation/28-pre-apply-verification-checklist.md
7. docs/20-implementation/30-final-status-and-user-checklist.md
```

## 17. 현재 남은 live 검증

서비스가 다시 올라와야 확인 가능한 것:

```text
EKS node/self-hosted runner 복구
Prometheus 실제 조회
quality-gate.yml 5분 health check live 실행
Slack 1차/2차 알림 실제 수신
Slack approval button 실제 클릭
deployment-action-executor Lambda dispatch
rollback.yml이 gympt-gitops values-prod.yaml 실제 rollback commit 생성
Argo CD rollback sync
최종 배포 완료 알림
```

apply 전에 이미 확인된 것:

```text
Lambda zip 생성
terraform fmt
terraform validate
terraform plan
GitHub token 권한
rollback workflow YAML
local fixture test
```
