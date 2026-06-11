# DOC-15. GitHub Actions Workflow Design

## 1. 목적

이 문서는 CD Quality Gate를 GitHub Actions workflow에 어떻게 연결할지 정의한다.

핵심은 기존 CD workflow가 Argo CD 배포 완료에서 끝나지 않고, 배포 직후 Prometheus 기반 health check를 수행한 뒤 CD 성공/실패를 결정하도록 확장하는 것이다.

## 2. Workflow 구성

추천 workflow는 두 개로 나눈다.

```text
.github/workflows/cd.yml
.github/workflows/quality-gate.yml
```

| Workflow | 역할 |
| --- | --- |
| `cd.yml` | GitOps image tag update, Argo CD automated sync 트리거 |
| `quality-gate.yml` | Prometheus alert/metric 조회, quality gate 판단, Slack 알림, EventBridge 이벤트 발행 |

## 3. 전체 실행 순서

```text
1. GitHub Actions CD 시작
2. Docker image build
3. ECR push
4. GitOps Repository image tag 수정
5. Argo CD automated sync가 Git 변경 감지
6. self-hosted runner에서 Kubernetes rollout status 확인
7. Prometheus alert 조회
8. Prometheus metric 조회
9. Quality Gate 평가
10. 정상이면 CD 성공
11. 실패면 Slack 1차 알림
12. 실패면 EventBridge DeploymentFailed 이벤트 발행
13. GitHub Actions job 실패 처리
```

## 4. `cd.yml` 설계

### Trigger

```yaml
on:
  push:
    branches:
      - main
      - dev
  workflow_dispatch:
```

### Required Secrets

```text
AWS_ROLE_ARN
GITOPS_PAT
SLACK_WEBHOOK_URL
PROMETHEUS_URL
```

`gympt-ops`와 동일하게 GitHub Actions는 `GITOPS_PAT`로 `hj-3/gympt-gitops` main branch의 values file을 직접 갱신한다. Argo CD 직접 sync용 `ARGOCD_SERVER`, `ARGOCD_AUTH_TOKEN`은 기본 CD 경로에서 사용하지 않는다.

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
COMMIT_SHA
K8S_NAMESPACE
K8S_DEPLOYMENT
```

### Job 구조

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
      - name: Configure AWS credentials
      - name: Login to ECR
      - name: Build image
      - name: Push image
      - name: Update GitOps image tag
      - name: Wait Argo CD application
      - name: Check Kubernetes rollout
      - name: Run post-deploy quality gate
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
      commit_sha:
        required: true
        type: string
      argocd_app:
        required: true
        type: string
```

### Job 구조

```yaml
jobs:
  post-deploy-health-check:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
      - name: Query Prometheus alerts
      - name: Query Prometheus metrics
      - name: Build Grafana links
      - name: Evaluate quality gate
      - name: Send Slack first alert
        if: failure()
      - name: Publish EventBridge DeploymentFailed
        if: failure()
```

## 6. Quality Gate Script 매핑

| Step | Script | Output |
| --- | --- | --- |
| Query Prometheus alerts | `scripts/quality-gate/query-prometheus-alerts.sh` | `prometheus-alerts.json` |
| Query Prometheus metrics | `scripts/quality-gate/query-prometheus-metrics.sh` | `prometheus-metrics.json` |
| Build Grafana links | `scripts/quality-gate/build-grafana-links.py` | `grafana-links.json` |
| Evaluate gate | `scripts/quality-gate/evaluate-quality-gate.py` | `quality-gate-result.json` |
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

초기 MVP에서는 위 실패들은 GitHub Actions 실패로만 처리하고, `DeploymentFailed`는 배포 후 품질 검증 실패에 집중하는 것이 좋다.

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
