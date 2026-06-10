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
  -> GitOps Repository image tag updated
  -> Argo CD app sync / app wait
  -> Amazon EKS rollout status
  -> Prometheus API
  -> Quality Gate decision
```

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
  -> Prometheus
  -> Grafana Dashboard
  -> CD Quality Gate
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
