# DOC-15. GitHub Actions Workflow Design

## 1. 목적

이 문서는 CD Quality Gate를 GitHub Actions workflow에 어떻게 연결할지 정의한다.

핵심은 기존 `gympt-ops` CD workflow가 담당하는 build/test/ECR push/GitOps values update/Argo CD sync를 다시 만들지 않고, 배포 직후 Prometheus 기반 health check와 AI incident analysis를 추가하는 것이다.

## 2. Workflow 구성

추천 workflow는 두 개로 나눈다.

```text
.github/workflows/cd.yml
.github/workflows/quality-gate.yml
```

| Workflow | 역할 |
| --- | --- |
| `cd.yml` | 기존 배포 이후 Quality Gate를 수동 실행하거나 나중에 `gympt-ops` workflow에서 호출하기 위한 wrapper |
| `quality-gate.yml` | Prometheus alert/metric 조회, quality gate 판단, Slack 알림, EventBridge 이벤트 발행 |

## 3. 전체 실행 순서

```text
1. 기존 gympt-ops app CI/CD가 Docker image build, ECR push, GitOps values update 수행
2. 기존 Argo CD automated sync가 EKS에 backend-api-prod 배포
3. cd-quality-gate-architecture의 post-deploy wrapper 또는 quality-gate workflow 실행
4. self-hosted runner에서 Kubernetes rollout status 확인
5. Prometheus alert 조회
6. Prometheus metric 조회
7. Quality Gate 평가
8. 정상이면 배포 완료 Slack 알림
9. 실패면 Slack 1차 알림
10. 실패면 EventBridge DeploymentFailed 이벤트 발행
11. GitHub Actions job 실패 처리
```

## 4. `cd.yml` 설계

### Trigger

```yaml
on:
  workflow_dispatch:
```

### Required Secrets

```text
AWS_ROLE_ARN
SLACK_WEBHOOK_URL
PROMETHEUS_URL
```

`GITOPS_PAT`는 이 저장소의 필수 secret이 아니다. GitOps values update는 기존 `gympt-ops` app CI/CD가 이미 수행한다.

`PROMETHEUS_URL`은 EKS 내부 kube-prometheus-stack service를 사용한다.

```text
http://kube-prometheus-stack-prometheus.monitoring.svc:9090
```

따라서 Quality Gate workflow는 EKS/VPC 내부 self-hosted runner에서 실행한다.

### Required Inputs / Env

```text
SERVICE_NAME
ENVIRONMENT
IMAGE_TAG
K8S_NAMESPACE
K8S_DEPLOYMENT
```

### Job 구조

```yaml
jobs:
  quality-gate:
    uses: ./.github/workflows/quality-gate.yml
    secrets: inherit
    with:
      service: backend-api
      environment: prod
      namespace: gympt-prod
      deployment: backend-api-prod
      image_tag: <deployed-image-tag>
```

## 5. `quality-gate.yml` 설계

### 호출 방식

`quality-gate.yml`은 reusable workflow로 두는 것을 추천한다.

```yaml
on:
  workflow_call:
    inputs:
      service_name:
        required: true
        type: string
      environment:
        required: true
        type: string
      image_tag:
        required: true
        type: string
      namespace:
        required: true
        type: string
      deployment:
        required: true
        type: string
```

### Job 구조

```yaml
jobs:
  post-deploy-health-check:
    runs-on: [self-hosted, linux, eks]
    steps:
      - name: Checkout
      - name: Check Kubernetes rollout
      - name: Run 5-minute health check window
      - name: Build Grafana links
      - name: Send Slack deploy success
        if: success()
      - name: Send Slack first alert
        if: failure()
      - name: Publish EventBridge DeploymentFailed
        if: failure()
```

## 6. Quality Gate Script 매핑

| Step | Script | Output |
| --- | --- | --- |
| Run health check window | `scripts/quality-gate/run-health-check-window.sh` | `quality-gate-window-result.json`, `quality-gate-result.json` |
| Query Prometheus alerts | `scripts/quality-gate/query-prometheus-alerts.sh` | `prometheus-alerts-<sample>.json`, `prometheus-alerts.json` |
| Query Prometheus metrics | `scripts/quality-gate/query-prometheus-metrics.sh` | `prometheus-metrics-<sample>.json`, `prometheus-metrics.json` |
| Build Grafana links | `scripts/quality-gate/build-grafana-links.py` | `grafana-links.json` |
| Evaluate gate | `scripts/quality-gate/evaluate-quality-gate.py` | `quality-gate-result-<sample>.json` |
| Send Slack alert | `scripts/quality-gate/send-slack-first-alert.py` | Slack message |
| Publish event | `scripts/quality-gate/publish-eventbridge-event.sh` | EventBridge event |

## 7. 실패 처리 정책

Quality Gate 실패 시 workflow는 다음 순서로 처리한다.

```text
1. quality-gate-result.json 생성
2. Slack 1차 알림 전송
3. EventBridge DeploymentFailed 이벤트 발행
4. GitHub Actions job exit 1
```

중요한 점은 Slack 알림과 EventBridge 이벤트 발행이 실패하더라도, Quality Gate 실패 자체는 숨기지 않아야 한다는 것이다.

## 8. EventBridge 발행 조건

EventBridge 이벤트는 다음 조건에서만 발행한다.

```text
Kubernetes rollout은 완료됨
Prometheus alert 또는 metric 기준에서 실패함
quality-gate-result.status == "failed"
```

다음 경우는 별도 이벤트로 분리할 수 있다.

```text
Docker build 실패
ECR push 실패
GitOps update 실패
Argo CD sync 실패
Kubernetes rollout 실패
```

초기 MVP에서 build/ECR/GitOps/Argo CD 실패는 기존 `gympt-ops` 알림과 운영 흐름에 맡긴다. 이 저장소의 `DeploymentFailed`는 배포 후 품질 검증 실패에 집중한다.

## 9. Slack 알림 포함 정보

```text
Service
Environment
Image Tag
Commit SHA
Argo CD App
Detected At
Detected Alerts
Metrics
Grafana URL
Prometheus URL
Argo CD URL
GitHub Actions Run URL
```

## 10. 예시 실행 결과

정상:

```text
Argo CD sync completed
Kubernetes rollout completed
Prometheus alerts: no firing alerts
Quality Gate: passed
GitHub Actions: success
```

실패:

```text
Argo CD sync completed
Kubernetes rollout completed
Prometheus alerts: BackendHighErrorRate firing
Quality Gate: failed
Slack 1st alert sent
EventBridge DeploymentFailed published
GitHub Actions: failed
```

## 11. 구현 시 주의점

```text
Prometheus 조회 시 배포 직후 바로 판단하지 말고 3~5분 window를 둔다.
Argo CD sync 실패와 Prometheus quality gate 실패를 구분한다.
Slack 알림 실패 때문에 EventBridge 발행이 누락되지 않게 한다.
EventBridge payload에는 commit, image tag, alert 목록을 반드시 넣는다.
민감 정보는 Slack 메시지나 EventBridge detail에 포함하지 않는다.
```
