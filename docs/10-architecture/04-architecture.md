# DOC-04. Architecture

## 1. 전체 아키텍처

전체 구조는 두 단계로 나뉜다.

```text
1단계: CD Quality Gate
2단계: AI Incident Analysis Pipeline
```

## 2. 1단계: CD Quality Gate

```text
GitHub Actions CD
  -> GitOps Repository values-prod.yaml image tag push
  -> Argo CD automated sync
  -> Amazon EKS backend-api-prod rollout status
  -> self-hosted runner queries internal Prometheus API
  -> Quality Gate decision
```

이 구조는 `gympt-ops`와 동일하게 GitOps repository를 source of truth로 둔다. GitHub Actions가 `argocd app sync`를 직접 실행하지 않고, `hj-3/gympt-gitops` main branch에 image tag 변경 commit을 push하면 `backend-api-prod` Argo CD Application의 `syncPolicy.automated`가 변경을 감지해 EKS에 배포한다.

Prometheus는 외부 공개 URL이 아니라 EKS 내부 service를 사용한다.

```text
http://kube-prometheus-stack-prometheus.monitoring.svc:9090
```

따라서 Quality Gate는 EKS/VPC 내부 self-hosted runner에서 실행되어야 한다.

정상일 경우:

```text
Quality Gate decision
  -> CD Success
```

실패일 경우:

```text
Quality Gate decision
  -> CD Failed
  -> Slack 1st alert
  -> EventBridge DeploymentFailed
```

## 3. 2단계: AI Incident Analysis Pipeline

```text
EventBridge DeploymentFailed
  -> AWS Lambda analysis orchestrator
  -> Amazon Athena query templates
  -> Amazon S3 central logs
  -> Amazon S3 deployment-failures summary JSON
  -> AI Agent
  -> Slack 2nd alert
  -> Operator
```

AI Agent는 다음 정보를 함께 사용한다.

```text
Prometheus alerts
Athena summary JSON
Grafana dashboard links
Argo CD application link
Runbook alert-specific shell scripts
```

## 4. 데이터 흐름 관점

### Monitoring 데이터

```text
Service Metrics
  -> kube-prometheus-stack Prometheus
  -> Grafana Dashboard
  -> CD Quality Gate running on self-hosted runner
```

### 로그 분석 데이터

```text
ALB / WAF / CloudFront / Application Logs
  -> S3 central logs
  -> Athena Query
  -> S3 analysis result
  -> AI Agent
```

### 운영자 피드백

```text
AI Agent
  -> Slack 2nd alert
  -> Operator review
  -> Approve rollback / manual fix / DR
```

## 5. 다이어그램 파일

- [../../cd-quality-gate-ai-incident-analysis.drawio](../../cd-quality-gate-ai-incident-analysis.drawio)
