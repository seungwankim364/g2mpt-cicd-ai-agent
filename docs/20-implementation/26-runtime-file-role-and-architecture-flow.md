# DOC-31. Runtime File Role and Architecture Flow

이 문서는 `cd-quality-gate-ai-incident-analysis.drawio` 아키텍처를 실제 파일 실행 흐름으로 연결하기 위한 기준이다.

목표는 두 가지다.

1. 각 `yml`, `sh`, `py` 파일이 무슨 역할을 하는지 설명한다.
2. 아키텍처 흐름도를 완성할 때 어떤 파일을 어느 순서로 따라가면 되는지 정리한다.

이 문서는 `gympt-ops`를 수정하는 문서가 아니다. `gympt-ops`는 GitOps, Argo CD, Prometheus, Grafana, Athena 연결값을 확인하는 read-only reference다. 실제 추가/수정 대상은 이 저장소인 `cd-quality-gate-architecture`다.

## 1. 전체 실행 흐름

```text
Developer 또는 운영자
  -> 기존 gympt-ops app CI/CD 실행
  -> ECR image push
  -> gympt-ops GitOps values-dev/prod.yaml image tag update
  -> Argo CD backend-api-prod automated sync
  -> EKS gympt-prod/backend-api-prod 배포 완료
  -> 여기서부터 cd-quality-gate-architecture 확장 시작
  -> .github/workflows/quality-gate.yml 실행 또는 기존 workflow에서 호출
  -> scripts/cd/check-k8s-rollout.sh
  -> scripts/quality-gate/run-health-check-window.sh
     -> 5분 동안 Prometheus alert/metric 반복 조회
     -> scripts/quality-gate/query-prometheus-alerts.sh
     -> scripts/quality-gate/query-prometheus-metrics.sh
     -> scripts/quality-gate/evaluate-quality-gate.py
  -> 성공이면 scripts/quality-gate/send-slack-deploy-success.py
  -> 실패이면 scripts/quality-gate/build-grafana-links.py
  -> 실패이면 scripts/quality-gate/send-slack-first-alert.py
  -> 실패이면 scripts/quality-gate/publish-eventbridge-event.sh
  -> EventBridge cd-quality-gate-prod-bus
  -> lambda/analysis-orchestrator/app.py
  -> athena/templates/backend-api.json
  -> athena/queries/*.sql
  -> lambda/analysis-orchestrator/bedrock_agent.py
  -> fallback이면 ai-agent/app/analyzer.py
  -> ai-agent/app/slack_message_builder.py
  -> Slack #cd-deploy-alarm 2차 분석/승인 알림
  -> dashboard/server.mjs
  -> dashboard/src/main.js
  -> 운영자가 timeline, health, AI 분석, 승인 action, infra 상태 확인
```

## 1.1 현재 확정된 runtime architecture tree

아래 tree는 실제 실행 주체와 파일을 함께 보여준다. 이 tree를 기준으로 `cd-quality-gate-ai-incident-analysis.drawio`의 박스를 맞춘다.

```text
cd-quality-gate-runtime
  existing-gympt-ops-cicd
    owner: gympt-ops
    responsibility:
      - build/test
      - Docker image build
      - ECR push
      - GitOps values-dev/prod.yaml image tag update
      - prod values 변경 PR 또는 승인 흐름

  existing-argocd-automated-sync
    owner: gympt-ops
    file: ../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
    app: backend-api-prod
    source:
      repoURL: https://github.com/hj-3/gympt-gitops.git
      targetRevision: main
      path: charts/backend-api
      valueFiles: values-prod.yaml
    destination:
      namespace: gympt-prod
      deployment: backend-api-prod
    behavior:
      syncPolicy.automated.prune: true
      syncPolicy.automated.selfHeal: true

  quality-gate-extension
    owner: cd-quality-gate-architecture
    entrypoint: .github/workflows/quality-gate.yml
    wrapper: .github/workflows/cd.yml
    runner: [self-hosted, linux, eks]
    reason:
      - internal Kubernetes rollout 확인 필요
      - internal Prometheus service 접근 필요
    first-check:
      script: scripts/cd/check-k8s-rollout.sh
      reads:
        K8S_NAMESPACE: gympt-prod
        K8S_DEPLOYMENT: backend-api-prod

    prometheus
      url: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
      health-check-window:
        script: scripts/quality-gate/run-health-check-window.sh
        duration: 300s
        interval: 60s
        monitoredNamespaces:
          - gympt-prod
          - monitoring
          - posture-analysis
          - elasticache
        evaluatedAlertGroups:
          backend:
            - BackendHighErrorRate
            - BackendHighLatency
            - BackendPodRestarting
            - BackendDBPoolExhaustion
            - BackendHighMemoryUsage
          kubernetesAndSqs:
            - NodeHighCPUUsage
            - PodRestartFrequent
            - SQSQueueBacklog
            - SQSMessageAge
            - SQSDLQMessages
          gpuRedisBedrock:
            - GPUHighUtilization
            - GPUMemoryHigh
            - RedisConnectionError
            - RedisHighMemory
            - RedisHighEvictionRate
            - BedrockHighErrorRate
            - BedrockThrottling
        output: quality-gate-window-result.json
      query-alerts:
        script: scripts/quality-gate/query-prometheus-alerts.sh
        output: prometheus-alerts-<sample>.json
      query-metrics:
        script: scripts/quality-gate/query-prometheus-metrics.sh
        output: prometheus-metrics-<sample>.json

    decision
      script: scripts/quality-gate/evaluate-quality-gate.py
      input: prometheus-alerts-<sample>.json
      output: quality-gate-result-<sample>.json
      aggregate-output: quality-gate-result.json
      dashboard-links:
        - api-latency
        - eks-overview
        - jvm-metrics
        - gpu-metrics
        - redis-metrics
        - sqs-metrics
      pass:
        script: scripts/quality-gate/send-slack-deploy-success.py
        output: slack-deploy-success.json
      fail:
        grafana-link-script: scripts/quality-gate/build-grafana-links.py
        first-alert-script: scripts/quality-gate/send-slack-first-alert.py
        event-script: scripts/quality-gate/publish-eventbridge-event.sh
        event-bus: cd-quality-gate-prod-bus

  ai-incident-analysis
    trigger: EventBridge DeploymentFailed
    lambda: lambda/analysis-orchestrator/app.py
    athena-template: athena/templates/backend-api.json
    athena-queries: athena/queries/*.sql
    ai-analysis:
      bedrock-adapter: lambda/analysis-orchestrator/bedrock_agent.py
      model-id: anthropic.claude-3-haiku-20240307-v1:0
      fallback-analyzer: ai-agent/app/analyzer.py
      runbook-loader: ai-agent/app/runbook_loader.py
      slack-builder: ai-agent/app/slack_message_builder.py
    output:
      slack-channel: #cd-deploy-alarm
      message: rollback / DR / change approval recommendation

  dashboard-control-center
    owner: cd-quality-gate-architecture
    backend: dashboard/server.mjs
    frontend: dashboard/src/main.js
    static-entry: dashboard/index.html
    data-contract: dashboard/data-contracts/dashboard-data.schema.json
    demo-data: dashboard/src/data/sample-dashboard.js
    runtime-action-log: dashboard/runtime/actions.json
    local-api:
      - GET /api/dashboard
      - GET /api/actions
      - POST /api/actions
      - POST /api/infra/apply-plan
      - POST /api/infra/destroy-plan
    purpose:
      - Deployment Timeline 확인
      - 5분 Quality Gate Health 확인
      - AI Incident Analysis 확인
      - rollback/DR/manual_fix/change 승인 기록
      - Terraform apply/destroy plan 확인
```

중요한 점은 이 저장소가 기존 배포 앞단을 다시 만들지 않는다는 것이다. build, ECR push, GitOps values update, Argo CD automated sync는 이미 `gympt-ops`에 있다. 이 저장소는 그 이후의 post-deploy Quality Gate와 AI Incident Analysis만 추가한다.

## 2. draw.io 박스와 실제 파일 매핑

| draw.io 영역 | 실제 파일 | 역할 |
| --- | --- | --- |
| Existing app CI/CD | `gympt-ops` app workflows | build/test, ECR push, GitOps values image tag update |
| Post-deploy wrapper | `.github/workflows/cd.yml` | 기존 배포 이후 수동 또는 연동 방식으로 Quality Gate workflow 호출 |
| GitOps image tag update | existing `gympt-ops` app workflow | 이 저장소가 수행하지 않음. 기존 app CI/CD가 GitOps values-dev/prod.yaml을 갱신 |
| Argo CD automated sync | `argocd/applications/prod/backend-api.yaml` in `gympt-ops` | GitOps 변경을 감지해 `backend-api-prod`를 자동 sync |
| Kubernetes rollout | `scripts/cd/check-k8s-rollout.sh` | self-hosted runner에서 `K8S_NAMESPACE=gympt-prod`, `K8S_DEPLOYMENT=backend-api-prod` rollout 상태 확인 |
| Quality Gate | `.github/workflows/quality-gate.yml` | rollout 확인 후 5분 Health Check Window를 실행하고, Slack 알림/EventBridge 발행을 처리 |
| Health Check Window | `scripts/quality-gate/run-health-check-window.sh` | 기본 300초 동안 60초 간격으로 0초~300초 지점까지 Prometheus alert/metric을 조회하고 sample 결과를 집계 |
| Prometheus alerts | `scripts/quality-gate/query-prometheus-alerts.sh` | Prometheus API에서 현재 alert 목록을 조회하거나 fixture로 대체 |
| Prometheus metrics | `scripts/quality-gate/query-prometheus-metrics.sh` | 배포 직후 판단에 필요한 metric snapshot을 조회 |
| Gate decision | `scripts/quality-gate/evaluate-quality-gate.py` | 각 sample에서 firing alert 중 서비스/namespace/alert name이 일치하는 항목이 있으면 실패 처리 |
| Grafana links | `scripts/quality-gate/build-grafana-links.py` | Slack 메시지에 넣을 Grafana dashboard URL 생성 |
| Slack 1차 실패 알림 | `scripts/quality-gate/send-slack-first-alert.py` | 5분 Health Check Window 실패 확정 후 `#cd-deploy-alarm`에 alert, Grafana, Prometheus, Argo CD, GitHub Actions 링크 포함 payload 생성/전송 |
| Slack 배포 완료 알림 | `scripts/quality-gate/send-slack-deploy-success.py` | Quality Gate 통과 시 배포 완료 payload 생성/전송 |
| EventBridge event | `scripts/quality-gate/publish-eventbridge-event.sh` | `DeploymentFailed` 이벤트를 만들고 `cd-quality-gate-prod-bus`로 발행 |
| Approved action event | `.github/workflows/approved-action.yml`, `scripts/quality-gate/publish-approved-action-event.sh` | 운영자 승인 내용을 `DeploymentActionApproved` 이벤트로 발행 |
| Slack approval handler | `lambda/slack-approval-handler/app.py`, `infra/terraform/apigateway.tf` | Slack 승인 버튼 요청을 검증하고 승인 이벤트를 EventBridge에 발행 |
| Deployment action executor | `lambda/deployment-action-executor/app.py` | 승인 이벤트를 받아 rollback/DR/manual fix/change workflow를 자동 dispatch |
| EventBridge bus/rule | `infra/terraform/eventbridge.tf` | 전용 bus와 `DeploymentFailed` rule 정의 |
| Lambda target | `infra/terraform/lambda.tf` | EventBridge 이후 실행될 Lambda와 환경변수 정의 |
| Lambda package | `scripts/lambda/package-analysis-orchestrator.sh` | Terraform이 참조하는 `build/analysis-orchestrator.zip` 생성. Bedrock adapter, `ai-agent` fallback, runbook, Athena query 포함 |
| Lambda Orchestrator | `lambda/analysis-orchestrator/app.py` | 이벤트 수신, Athena query 실행, summary 생성, AI Agent 호출, Slack 2차 알림 전송 |
| Athena query template | `athena/templates/backend-api.json` | backend-api 실패 시 실행할 SQL 목록 정의 |
| Athena SQL | `athena/queries/*.sql` | ALB, application, WAF 등 로그 분석 query |
| Bedrock AI analysis | `lambda/analysis-orchestrator/bedrock_agent.py` | alert와 Athena summary를 Bedrock 모델에 전달하고 원인 후보, 심각도, 추천 조치를 JSON으로 생성 |
| Local AI fallback | `ai-agent/app/analyzer.py` | Bedrock 비활성/실패 시 alert와 Athena signal을 읽고 rule 기반 추천 조치 생성 |
| AI Slack message | `ai-agent/app/slack_message_builder.py` | AI 분석 결과를 Slack 2차 알림 구조로 변환 |
| Runbook | `scripts/runbooks/*.sh` | alert별 사람이 확인할 운영 명령과 절차 |
| Dashboard backend | `dashboard/server.mjs` | 정적 대시보드와 local API를 제공하고 승인 action 기록, apply/destroy plan을 반환 |
| Dashboard frontend | `dashboard/src/main.js` | timeline, health, AI 분석, approval, infra/cost 화면을 렌더링하고 backend API 버튼을 호출 |
| Dashboard data contract | `dashboard/data-contracts/dashboard-data.schema.json` | live adapter가 받아야 하는 dashboard JSON 구조 정의 |
| Dashboard runtime actions | `dashboard/runtime/actions.json` | local backend가 기록한 승인 action 이력. Git에는 올리지 않음 |
| Local test | `scripts/test-local.sh` | 위 흐름을 fixture 기반으로 로컬에서 한 번에 검증 |

## 3. GitHub Actions yml 역할

### `.github/workflows/cd.yml`

이 파일은 기존 배포 이후 Quality Gate를 수동 실행하거나, 나중에 기존 `gympt-ops` workflow에서 호출하기 위한 post-deploy wrapper다.

실행 방식:

```text
GitHub Actions -> workflow_dispatch -> Post Deploy Quality Gate 실행
```

주요 입력:

```text
service: backend-api
environment: prod
image_tag: 337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api:latest
```

주요 환경값:

```text
namespace: gympt-prod
deployment: backend-api-prod
```

흐름:

```text
1. repository checkout
2. .github/workflows/quality-gate.yml 재사용 workflow 호출
3. quality-gate.yml 내부에서 rollout/Prometheus/Slack/EventBridge 처리
```

아키텍처 흐름도에서는 기존 `gympt-ops` 배포 뒤에 붙는 `CD Quality Gate extension` 진입점이다.

### `.github/workflows/quality-gate.yml`

이 파일은 배포 후 품질 검증의 중심이다.

실행 방식:

```text
cd.yml에서 workflow_call로 호출
또는 운영자가 workflow_dispatch로 직접 실행
```

주요 환경값:

```text
SERVICE_NAME=backend-api
ENVIRONMENT=prod
NAMESPACE=gympt-prod
DEPLOYMENT=backend-api-prod
ALERT_NAMES=BackendHighErrorRate,BackendHighLatency,BackendPodRestarting,BackendDBPoolExhaustion,BackendHighMemoryUsage,SQSQueueBacklog,SQSMessageAge,SQSDLQMessages,NodeHighCPUUsage,PodRestartFrequent,GPUHighUtilization,GPUMemoryHigh,RedisConnectionError,RedisHighMemory,RedisHighEvictionRate,BedrockHighErrorRate,BedrockThrottling
MONITORED_NAMESPACES=gympt-prod,monitoring,posture-analysis,elasticache
EVENT_BUS_NAME=cd-quality-gate-prod-bus
SLACK_CHANNEL=#cd-deploy-alarm
```

흐름:

```text
1. Kubernetes rollout 확인
2. 5분 Health Check Window 실행
3. 60초 간격으로 Prometheus alert/metric 조회
4. 각 sample마다 Quality Gate pass/fail 판단
5. 전체 window 결과를 quality-gate-result.json으로 집계
6. Grafana link 생성
7. 실패하면 Slack 1차 알림 생성/전송
8. 성공하면 Slack 배포 완료 알림 생성/전송
9. 실패하면 EventBridge DeploymentFailed 이벤트 발행
10. artifact 업로드
11. 실패이면 workflow 자체를 실패 처리
```

아키텍처 흐름도에서는 `Quality Gate`, `Prometheus`, `Grafana`, `Slack 1st alert`, `EventBridge` 박스를 연결하는 파일이다.

### `.github/workflows/cd-quality-gate-sample.yml`

이 파일은 실제 운영 workflow가 아니라 샘플 실행 흐름이다.

역할:

```text
문서/시연용으로 Quality Gate 흐름을 빠르게 이해하기 위한 sample workflow
```

아키텍처 흐름도에서는 필수 운영 경로가 아니라 demo/reference 경로로 표현한다.

## 4. CD shell script 역할

### `scripts/cd/update-gitops-image-tag.sh`

역할:

```text
GitOps repository의 values file에서 image tag를 새 배포 tag로 변경하고 main branch에 push하는 선택 보조 도구다.
```

현재 기본 통합 흐름에서는 이 script를 사용하지 않는다. 기존 `gympt-ops` app CI/CD가 이미 ECR push와 GitOps values update를 담당한다.

읽는 값:

```text
SERVICE_NAME
ENVIRONMENT
IMAGE_TAG
GITOPS_REPO
GITOPS_PAT
VALUES_FILE
```

실제 동작:

```text
1. GITOPS_REPO, GITOPS_PAT, VALUES_FILE 중 하나라도 없으면 dry-run으로 종료
2. https://x-access-token:<GITOPS_PAT>@github.com/hj-3/gympt-gitops.git 형태로 GitOps repository clone
3. VALUES_FILE 존재 확인
4. yq가 있으면 .image.tag를 IMAGE_TAG로 치환
5. yq가 없으면 sed fallback으로 tag 값을 치환
6. github-actions[bot] author로 git commit 생성
7. origin main rebase 후 main branch에 push
8. 변경 commit SHA 출력
```

`gympt-ops` 기준 연결값:

```text
VALUES_FILE=charts/backend-api/values-prod.yaml
image repository=337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api
target repository=hj-3/gympt-gitops
target branch=main
```

아키텍처 흐름도에서는 기존 `gympt-ops` app CI/CD가 GitOps repo에 desired state 변경을 넣는 화살표에 해당한다. 이 저장소의 script는 나중에 독립 실행/테스트/수동 운영이 필요할 때만 사용한다.

### Argo CD automated sync

역할:

```text
hj-3/gympt-gitops main branch 변경을 감지해 backend-api-prod를 EKS에 자동 배포한다.
```

기준 파일:

```text
../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
```

핵심 설정:

```text
repoURL=https://github.com/hj-3/gympt-gitops.git
targetRevision=main
path=charts/backend-api
valueFiles=values-prod.yaml
destination namespace=gympt-prod
syncPolicy.automated.prune=true
syncPolicy.automated.selfHeal=true
```

이 단계는 이 저장소에서 실행하는 script가 아니다. `gympt-ops`에 이미 존재하는 Argo CD Application이 수행한다.

### `scripts/cd/wait-argocd-app.sh`

역할:

```text
Argo CD application을 수동으로 sync하고 health/sync 완료까지 기다리는 선택 도구다.
```

읽는 값:

```text
ARGOCD_APP=backend-api-prod
ARGOCD_TIMEOUT=300
```

실제 동작:

```text
1. argocd CLI 설치 여부 확인
2. argocd app sync backend-api-prod
3. argocd app wait backend-api-prod --health --sync
4. argocd app get backend-api-prod
```

기본 CD 경로에서는 사용하지 않는다. `gympt-ops` 방식은 GitOps push 후 Argo CD `syncPolicy.automated`에 맡긴다.

아키텍처 흐름도에서는 수동 운영/장애 대응 보조 도구로만 표현한다.

### `scripts/cd/check-k8s-rollout.sh`

역할:

```text
EKS에 반영된 Kubernetes deployment rollout이 정상인지 확인한다.
```

읽는 값:

```text
K8S_NAMESPACE=gympt-prod
K8S_DEPLOYMENT=backend-api-prod
```

아키텍처 흐름도에서는 `Amazon EKS` 배포 완료 여부를 확인하는 검증 화살표다.

## 5. Quality Gate script 역할

### `scripts/quality-gate/query-prometheus-alerts.sh`

역할:

```text
Prometheus에서 현재 firing/pending/inactive alert 목록을 가져온다.
```

읽는 값:

```text
PROMETHEUS_URL
OUTPUT_FILE=prometheus-alerts.json
```

결과:

```text
prometheus-alerts.json
```

이 파일이 만든 JSON을 `evaluate-quality-gate.py`가 읽는다.

### `scripts/quality-gate/query-prometheus-metrics.sh`

역할:

```text
배포 직후 Prometheus metric snapshot을 가져온다.
```

읽는 값:

```text
PROMETHEUS_URL
SERVICE_NAME
NAMESPACE
OUTPUT_FILE=prometheus-metrics.json
```

결과:

```text
prometheus-metrics.json
```

현재 pass/fail의 직접 기준은 alert이고, metric 파일은 artifact와 분석 보조 자료로 남긴다.

### `scripts/quality-gate/evaluate-quality-gate.py`

역할:

```text
Prometheus alert JSON을 읽고 CD를 통과시킬지 실패시킬지 결정한다.
```

읽는 파일:

```text
prometheus-alerts.json
```

읽는 인자:

```text
--service backend-api
--namespace gympt-prod
--alert-names BackendHighErrorRate,...,BedrockThrottling
--monitored-namespaces gympt-prod,monitoring,posture-analysis,elasticache
--output-file quality-gate-result.json
```

판단 기준:

```text
1. alert state가 firing인지 확인
2. alert name이 평가 대상 목록에 있는지 확인
3. service label이 있으면 backend-api와 일치하는지 확인
4. namespace label이 있으면 monitored namespace 목록에 포함되는지 확인
5. 하나라도 매칭되면 failed
6. 매칭되는 firing alert가 없으면 passed
```

결과:

```text
quality-gate-result.json
```

아키텍처 흐름도에서는 `Quality Gate decision` 박스의 핵심 파일이다.

### `scripts/quality-gate/build-grafana-links.py`

역할:

```text
Slack 알림에 넣을 Grafana dashboard link를 만든다.
```

읽는 값:

```text
base-url=https://grafana.g2mpt.com
dashboard-uid=api-latency
dashboard-uid=eks-overview
dashboard-uid=jvm-metrics
dashboard-uid=gpu-metrics
dashboard-uid=redis-metrics
dashboard-uid=sqs-metrics
service=backend-api
namespace=gympt-prod
```

결과:

```text
grafana-links.json
```

이 파일 결과는 1차 Slack 알림과 EventBridge event detail에 들어간다.

### `scripts/quality-gate/send-slack-first-alert.py`

역할:

```text
Quality Gate 실패 시 Slack 1차 알림 payload를 만들거나 webhook으로 전송한다.
```

읽는 파일:

```text
quality-gate-result.json
grafana-links.json
```

읽는 값:

```text
SLACK_WEBHOOK_URL
SLACK_WEBHOOK_SECRET_ARN
SLACK_CHANNEL=#cd-deploy-alarm
GITHUB_RUN_URL
```

결과:

```text
slack-first-alert.json
```

아키텍처 흐름도에서는 `Slack 1st alert` 박스다.

### `scripts/quality-gate/send-slack-deploy-success.py`

역할:

```text
Quality Gate 통과 시 Slack 배포 완료 알림 payload를 만들거나 webhook으로 전송한다.
```

읽는 값:

```text
service=backend-api
namespace=gympt-prod
image-tag=<배포 image tag>
SLACK_CHANNEL=#cd-deploy-alarm
GITHUB_RUN_URL
```

결과:

```text
slack-deploy-success.json
```

아키텍처 흐름도에서는 정상 배포 경로의 `Slack deploy complete` 박스다.

### `scripts/quality-gate/publish-eventbridge-event.sh`

역할:

```text
Quality Gate 실패 내용을 EventBridge DeploymentFailed 이벤트로 발행한다.
```

읽는 파일:

```text
quality-gate-result.json
grafana-links.json
```

읽는 값:

```text
EVENT_BUS_NAME=cd-quality-gate-prod-bus
AWS_REGION=ap-northeast-2
SERVICE_NAME=backend-api
ENVIRONMENT=prod
IMAGE_TAG
GITHUB_SHA
```

결과:

```text
deployment-failed-event.json
```

실제 AWS 발행:

```text
aws events put-events --event-bus-name cd-quality-gate-prod-bus
```

아키텍처 흐름도에서는 GitHub Actions에서 AWS EventBridge로 넘어가는 연결이다.

## 5.1 Lambda 패키징 script 역할

### `scripts/lambda/package-analysis-orchestrator.sh`

역할:

```text
Terraform apply 전에 Lambda 배포 zip을 만든다.
```

생성 파일:

```text
build/analysis-orchestrator.zip
```

zip에 포함되는 파일:

```text
app.py
ai_agent_adapter.py
ai_agent/analyzer.py
ai_agent/runbook_loader.py
ai_agent/slack_message_builder.py
athena/queries/*.sql
athena/templates/*.json
scripts/runbooks/*.sh
```

실행:

```bash
scripts/lambda/package-analysis-orchestrator.sh
```

이 파일이 없으면 `infra/terraform/lambda.tf`의 `filename = "build/analysis-orchestrator.zip"` 때문에 Terraform apply가 실패한다.

## 6. Terraform yml/tf 역할

Terraform은 AWS 리소스를 생성/관리한다.

| 파일 | 역할 |
| --- | --- |
| `infra/terraform/providers.tf` | AWS provider와 default tag 기준 |
| `infra/terraform/variables.tf` | environment, owner, auto_stop 등 입력값과 validation |
| `infra/terraform/main.tf` | 공통 local name/tag 정의 |
| `infra/terraform/eventbridge.tf` | `cd-quality-gate-prod-bus`와 `DeploymentFailed` rule |
| `infra/terraform/lambda.tf` | Lambda function, 환경변수, concurrency 제한 |
| `infra/terraform/iam.tf` | Lambda/EventBridge/Athena/S3 접근 권한 |
| `infra/terraform/s3.tf` | Athena 결과와 deployment failure 결과 저장 bucket/lifecycle |
| `infra/terraform/athena.tf` | Athena database, workgroup, output location |
| `infra/terraform/outputs.tf` | bus name, bucket, Slack channel 등 출력값 |

아키텍처 흐름도에서는 `AWS EventBridge`, `Lambda`, `Athena`, `S3` 박스를 실제 AWS 리소스로 만드는 영역이다.

## 7. Lambda Orchestrator py 역할

### `lambda/analysis-orchestrator/app.py`

역할:

```text
EventBridge DeploymentFailed 이벤트를 받아 Athena 로그 분석과 AI Agent 분석을 실행한다.
```

입력:

```text
EventBridge detail
```

필수 detail:

```text
deploymentId
service
environment
failedAt
```

흐름:

```text
1. parse_deployment_failed_event()로 이벤트 detail 검증
2. build_analysis_window()로 실패 시점 기준 -10분/+5분 분석 구간 생성
3. start_athena_queries()로 athena/templates/<service>.json 읽기
4. template에 적힌 athena/queries/*.sql 실행
5. wait_or_collect_query_results()로 query 결과 상태 수집
6. build_summary()로 athena-summary 구조 생성
7. write_summary_to_s3()로 S3 또는 local path에 summary 저장
8. invoke_ai_agent()로 Bedrock AI 분석 호출
9. send_second_slack_alert()로 Secrets Manager의 Slack webhook을 읽고 Slack 2차 알림 전송
```

아키텍처 흐름도에서는 `Lambda analysis orchestrator` 박스의 중심 파일이다.

### `lambda/analysis-orchestrator/bedrock_agent.py`

역할:

```text
Athena summary와 Prometheus alert를 Amazon Bedrock 모델에 전달해 원인 후보와 추천 조치를 JSON으로 생성한다.
```

읽는 값:

```text
BEDROCK_ENABLED
BEDROCK_MODEL_ID
BEDROCK_REGION
BEDROCK_MAX_TOKENS
```

출력:

```text
aiResult.analysisEngine=bedrock
aiResult.slackPayload
```

주의:

```text
Bedrock 호출 실패, 권한 부족, 모델 access 미설정 시 app.py가 local ai-agent fallback으로 전환한다.
```

### `lambda/analysis-orchestrator/ai_agent_adapter.py`

역할:

```text
Bedrock이 비활성화되었거나 실패했을 때 Lambda 로컬 실행용 fallback 분석 결과를 만든다.
```

사용 위치:

```text
app.py의 invoke_ai_agent()
```

## 8. AI Agent py 역할

### `ai-agent/app/main.py`

역할:

```text
로컬 또는 API 형태로 Athena summary를 입력받아 AI 추천 결과와 Slack 2차 알림 payload를 만든다.
```

읽는 파일:

```text
athena-summary.sample.json 또는 Lambda가 만든 athena-summary.json
```

결과:

```text
ai-recommendation.json
slack-second-alert.json
```

### `ai-agent/app/analyzer.py`

역할:

```text
alert, Athena signal, runbook을 바탕으로 원인 후보와 추천 조치를 만든다.
```

판단 방식:

```text
critical alert가 있으면 rollback 추천
WAFBlockedRequestSpike는 manual_fix 추천
그 외는 observe/manual review 중심
```

아키텍처 흐름도에서는 `AI Agent analysis` 박스다.

### `ai-agent/app/runbook_loader.py`

역할:

```text
alert name에 맞는 scripts/runbooks/*.sh 경로를 찾아 AI Agent 결과에 붙인다.
```

예시:

```text
BackendHighErrorRate -> scripts/runbooks/backend-high-error-rate.sh
BackendDBPoolExhaustion -> scripts/runbooks/backend-db-pool-exhaustion.sh
BackendHighMemoryUsage -> scripts/runbooks/backend-high-memory-usage.sh
```

### `ai-agent/app/slack_message_builder.py`

역할:

```text
AI Agent 추천 결과를 Slack 2차 알림 JSON 구조로 변환한다.
```

Slack 2차 알림에 포함할 내용:

```text
원인 후보
근거
추천 조치
승인 필요 여부
rollback/change/DR 판단
```

### `ai-agent/app/prompt_builder.py`

역할:

```text
나중에 실제 LLM을 붙일 때 사용할 prompt 입력 구조를 만든다.
```

현재 scaffold에서는 rule-based analyzer가 우선 동작한다.

### `ai-agent/app/schemas.py`

역할:

```text
AI Agent 입출력 구조를 코드에서 재사용하기 위한 schema/helper 위치다.
```

## 9. Config yaml 역할

| 파일 | 역할 |
| --- | --- |
| `config/services/backend-api.yaml` | backend-api의 namespace, deployment, Argo CD app, chart path, values file, ingress host 기준 |
| `config/services/posture-analysis-service.yaml` | posture-analysis-service 확장용 서비스 기준 |
| `config/services/worker-lambda.yaml` | worker/lambda 계열 확장용 서비스 기준 |
| `config/quality-gate/alert-mapping.yaml` | 서비스별 평가 alert 목록과 runbook 매핑 |
| `config/quality-gate/grafana-dashboards.yaml` | Grafana base URL, dashboard UID, panel 기준 |
| `config/quality-gate/thresholds.yaml` | Quality Gate threshold 기준 |
| `config/environments/dev.yaml` | dev 환경 EventBridge, region, Slack, 비용 태그 기준 |
| `config/environments/prod.yaml` | prod 환경 EventBridge, region, Slack, 비용 태그 기준 |
| `config/gympt-ops/connection-values.yaml` | `gympt-ops`에서 읽어온 실제 연결값 정리 |

아키텍처 흐름도에서는 직접 실행되는 파일은 아니지만, 각 박스가 어떤 실제 값으로 연결되는지 설명하는 근거 파일이다.

## 10. Athena 파일 역할

| 파일 | 역할 |
| --- | --- |
| `athena/templates/backend-api.json` | backend-api 장애 분석 시 실행할 query 목록 |
| `athena/templates/posture-analysis-service.json` | posture-analysis-service 확장용 query 목록 |
| `athena/templates/worker-lambda.json` | worker/lambda 확장용 query 목록 |
| `athena/queries/*.sql` | 실제 Athena에서 실행할 SQL |
| `athena/schemas/*.sql` | 외부 테이블 생성 기준 |

Lambda는 `service=backend-api` 이벤트를 받으면 `athena/templates/backend-api.json`을 읽고, 그 안에 적힌 SQL 파일을 실행한다.

## 11. Schema와 fixture 역할

| 파일/폴더 | 역할 |
| --- | --- |
| `schemas/eventbridge/deployment-failed.schema.json` | EventBridge `DeploymentFailed` event 구조 |
| `schemas/slack/first-alert.schema.json` | Slack 1차 알림 구조 |
| `schemas/slack/second-alert.schema.json` | Slack 2차 알림 구조 |
| `schemas/ai-agent/ai-recommendation.schema.json` | AI Agent 추천 결과 구조 |
| `schemas/ai-agent/athena-summary.schema.json` | Athena summary 구조 |
| `schemas/rollback/rollback-request.schema.json` | 승인 기반 rollback 요청 구조 |
| `tests/fixtures/*.json` | 로컬 테스트용 Prometheus, Athena, EventBridge sample |

아키텍처 흐름도에서는 데이터가 박스 사이를 이동할 때 어떤 JSON 형태인지 설명하는 보조 자료다.

## 12. 로컬에서 흐름을 검증하는 파일

### `scripts/test-local.sh`

역할:

```text
실제 AWS, Slack, Prometheus 없이 fixture 기반으로 전체 흐름을 검증한다.
```

검증 범위:

```text
1. shell syntax
2. Python compile
3. JSON fixture/schema 확인
4. Quality Gate pass fixture
5. Quality Gate fail fixture
6. Slack payload 생성
7. EventBridge dry-run payload 생성
8. AI Agent와 Lambda local 실행
9. AWS stop script help 확인
```

실행:

```bash
scripts/test-local.sh
```

아키텍처 흐름도를 완성한 뒤 가장 먼저 실행해야 하는 검증 파일이다.

## 13. draw.io 완성 기준

`cd-quality-gate-ai-incident-analysis.drawio`를 완성할 때는 아래 순서대로 박스를 배치하면 된다.

### 정상 배포 경로

```text
Existing gympt-ops app CI/CD
  -> build/test/ECR push
  -> GitOps values-dev/prod.yaml image tag update
  -> Argo CD backend-api-prod automated sync
  -> Amazon EKS gympt-prod/backend-api-prod rollout
  -> cd-quality-gate-architecture extension starts
  -> Quality Gate
  -> Prometheus alert/metric check
  -> Quality Gate passed
  -> Slack #cd-deploy-alarm deploy complete
```

관련 파일:

```text
existing gympt-ops app workflow
../gympt-ops/gympt-gitops/argocd/applications/prod/backend-api.yaml
.github/workflows/cd.yml
scripts/cd/check-k8s-rollout.sh
.github/workflows/quality-gate.yml
scripts/quality-gate/query-prometheus-alerts.sh
scripts/quality-gate/query-prometheus-metrics.sh
scripts/quality-gate/evaluate-quality-gate.py
scripts/quality-gate/send-slack-deploy-success.py
```

### 실패 감지 경로

```text
Quality Gate
  -> Prometheus firing alert matched
  -> Grafana link build
  -> Slack #cd-deploy-alarm first failure alert
  -> EventBridge DeploymentFailed publish
```

관련 파일:

```text
scripts/quality-gate/evaluate-quality-gate.py
scripts/quality-gate/build-grafana-links.py
scripts/quality-gate/send-slack-first-alert.py
scripts/quality-gate/publish-eventbridge-event.sh
schemas/eventbridge/deployment-failed.schema.json
```

### AI 분석 경로

```text
EventBridge cd-quality-gate-prod-bus
  -> Lambda analysis orchestrator
  -> Athena query template
  -> Athena SQL
  -> Athena summary
  -> AI Agent
  -> Slack #cd-deploy-alarm rollback/DR/change approval alert
```

관련 파일:

```text
infra/terraform/eventbridge.tf
infra/terraform/lambda.tf
lambda/analysis-orchestrator/app.py
athena/templates/backend-api.json
athena/queries/*.sql
ai-agent/app/analyzer.py
ai-agent/app/runbook_loader.py
ai-agent/app/slack_message_builder.py
schemas/ai-agent/ai-recommendation.schema.json
schemas/slack/second-alert.schema.json
```

### 운영자 승인/조치 경로

```text
Slack 2차 분석 알림
  -> operator review
  -> rollback 승인 또는 DR/change 검토
  -> runbook 실행
  -> 결과 Slack 공유
```

관련 파일:

```text
docs/20-implementation/25-rollback-workflow-design.md
scripts/runbooks/*.sh
schemas/rollback/rollback-request.schema.json
```

## 14. 실제 값 기준 요약

| 항목 | 값 |
| --- | --- |
| service | `backend-api` |
| environment | `prod` |
| namespace | `gympt-prod` |
| deployment | `backend-api-prod` |
| Argo CD app | `backend-api-prod` |
| values file | `charts/backend-api/values-prod.yaml` |
| ECR image | `337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api` |
| Grafana | `https://grafana.g2mpt.com` |
| Grafana dashboard UID | `api-latency`, `eks-overview`, `jvm-metrics`, `gpu-metrics`, `redis-metrics`, `sqs-metrics` |
| EventBridge bus | `cd-quality-gate-prod-bus` |
| Slack channel | `#cd-deploy-alarm` |
| AWS region | `ap-northeast-2` |

## 15. 파일을 읽는 순서

처음부터 끝까지 이해하려면 아래 순서로 읽는다.

```text
1. cd-quality-gate-ai-incident-analysis.drawio
2. docs/10-architecture/04-architecture.md
3. docs/10-architecture/05-detailed-flows.md
4. docs/10-architecture/06-components.md
5. docs/20-implementation/14-implementation-file-architecture.md
6. docs/20-implementation/26-runtime-file-role-and-architecture-flow.md
7. .github/workflows/cd.yml
8. .github/workflows/quality-gate.yml
9. scripts/cd/*.sh
10. scripts/quality-gate/*.sh
11. scripts/quality-gate/*.py
12. infra/terraform/*.tf
13. lambda/analysis-orchestrator/app.py
14. athena/templates/backend-api.json
15. athena/queries/*.sql
16. ai-agent/app/*.py
17. scripts/runbooks/*.sh
18. scripts/test-local.sh
```

## 16. 최종 검증 명령

문서와 흐름을 수정한 뒤에는 아래 명령으로 확인한다.

```bash
scripts/test-local.sh
terraform -chdir=infra/terraform fmt -check
```

`pytest` 기반 테스트는 로컬 환경에 `pytest`가 설치되어 있어야 실행할 수 있다.
