# DOC-25. Configuration Reference

## 1. 목적

CD Quality Gate와 AI Incident Analysis Pipeline에서 사용하는 설정 파일의 역할, 필드, 예시 값을 정리한다.

구현자는 이 문서를 기준으로 서비스별 설정, threshold, alert mapping, dashboard link template을 작성한다.

## 2. 설정 파일 목록

```text
config/services/{service}.yaml
config/quality-gate/thresholds.yaml
config/quality-gate/alert-mapping.yaml
config/quality-gate/grafana-dashboards.yaml
athena/templates/{service}.json
```

## 3. `config/services/{service}.yaml`

서비스별 배포 검증 대상과 기본 메타데이터를 정의한다.

예시:

```yaml
service: backend-api
environment: prod
namespace: prod
deployment: backend-api
argocdApp: backend-api-prod
owner: platform-team
qualityGate:
  enabled: true
  waitAfterDeploySeconds: 120
  alertNames:
    - BackendHighErrorRate
    - BackendHighLatency
    - BackendPodRestarting
grafana:
  dashboardKey: backend-api
runbooks:
  default: backend-high-error-rate.sh
```

필드 설명:

| 필드 | 필수 | 설명 |
| --- | --- | --- |
| `service` | yes | 서비스 식별자 |
| `environment` | yes | `dev`, `staging`, `prod` |
| `namespace` | yes | Kubernetes namespace |
| `deployment` | yes | Kubernetes deployment name |
| `argocdApp` | yes | Argo CD application name |
| `owner` | no | 담당 팀 |
| `qualityGate.enabled` | yes | Quality Gate 적용 여부 |
| `qualityGate.waitAfterDeploySeconds` | no | 배포 후 metric 안정화 대기 시간 |
| `qualityGate.alertNames` | yes | 배포 검증에 사용할 alert 목록 |
| `grafana.dashboardKey` | no | dashboard template key |
| `runbooks.default` | no | 기본 runbook script |

## 4. `config/quality-gate/thresholds.yaml`

서비스 또는 공통 threshold를 정의한다.

예시:

```yaml
defaults:
  errorRatePercent:
    warning: 2
    critical: 5
  p95LatencyMs:
    warning: 800
    critical: 1500
  podRestartIncrease:
    warning: 1
    critical: 3

services:
  backend-api:
    errorRatePercent:
      warning: 1
      critical: 3
    p95LatencyMs:
      warning: 500
      critical: 1000
```

적용 순서:

```text
service-specific threshold
  -> default threshold
  -> script fallback threshold
```

## 5. `config/quality-gate/alert-mapping.yaml`

Prometheus alert와 runbook, Athena query, 추천 조치 후보를 연결한다.

예시:

```yaml
alerts:
  BackendHighErrorRate:
    severity: critical
    runbook: backend-high-error-rate.sh
    athenaQueries:
      - alb-5xx-errors
      - application-error-patterns
    recommendedActions:
      - rollback
      - manual_fix

  WAFBlockedRequestSpike:
    severity: warning
    runbook: waf-blocked-request-spike.sh
    athenaQueries:
      - waf-blocked-requests
    recommendedActions:
      - manual_fix
      - observe
```

## 6. `config/quality-gate/grafana-dashboards.yaml`

Slack 메시지에 포함할 Grafana link template을 정의한다.

예시:

```yaml
baseUrl: https://grafana.example.com

dashboards:
  backend-api:
    uid: backend-api-overview
    title: Backend API Overview
    panels:
      errorRate: 12
      latency: 18
      podRestart: 24
    variables:
      service: backend-api
      namespace: prod
```

생성 URL 예시:

```text
https://grafana.example.com/d/backend-api-overview?var-service=backend-api&var-namespace=prod&from=now-30m&to=now
```

## 7. `athena/templates/{service}.json`

서비스별 Athena query 실행 목록과 분석 window를 정의한다.

예시:

```json
{
  "service": "backend-api",
  "environment": "prod",
  "windowMinutesBefore": 10,
  "windowMinutesAfter": 5,
  "queries": [
    {
      "id": "alb-5xx-errors",
      "file": "alb-5xx-errors.sql",
      "required": true
    },
    {
      "id": "application-error-patterns",
      "file": "application-error-patterns.sql",
      "required": true
    }
  ]
}
```

## 8. 환경별 Override

환경별 설정 차이는 별도 파일로 분리할 수 있다.

```text
config/env/dev.yaml
config/env/prod.yaml
```

예시:

```yaml
environment: prod
qualityGate:
  enabled: true
  failOnWarning: false
notifications:
  slackChannel: "#prod-deployments"
```

## 9. 검증 기준

```text
모든 YAML/JSON 설정은 schema validation 대상
service 이름은 directory/file naming과 일치
alertNames는 alert-mapping.yaml에 존재
grafana dashboardKey는 grafana-dashboards.yaml에 존재
athena query id는 athena/templates와 SQL 파일에 존재
```

