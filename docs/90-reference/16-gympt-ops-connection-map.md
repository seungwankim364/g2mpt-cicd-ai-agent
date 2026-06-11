# DOC-30. GymPT Ops Connection Map

## 1. 목적

`gympt-ops`를 읽기 전용으로 참고해서, CD Quality Gate를 나중에 실제 서비스에 붙일 때 필요한 연결값을 정리한다.

이 문서는 `gympt-ops` 파일을 수정하지 않는다. 실제 적용 전에는 여기의 값을 기준으로 `cd-quality-gate-architecture` 안의 config와 workflow를 보정한다.

## 2. 참고한 저장소 구조

```text
../gympt-ops/gympt-app
../gympt-ops/gympt-gitops
../gympt-ops/gympt-infra
```

주요 연결 지점:

```text
gympt-app      -> 서비스 소스, Dockerfile, 기존 CI/CD 후보
gympt-gitops   -> Argo CD Application, Helm chart, values, monitoring rule
gympt-infra    -> EKS, S3 logs, Athena, EventBridge, AWS account/region 근거
```

## 3. Argo CD Application 연결값

### Prod

| Service | Argo CD App | Namespace | Chart Path | Values File |
| --- | --- | --- | --- | --- |
| backend-api | `backend-api-prod` | `gympt-prod` | `charts/backend-api` | `values-prod.yaml` |
| agent-service | `agent-service-prod` | `gympt-prod` | `charts/agent-service` | `values-prod.yaml` |
| posture-analysis-service | `posture-analysis-service-prod` | `gympt-prod` | `charts/posture-analysis-service` | `values-prod.yaml` |
| kvs-consumer-service | `kvs-consumer-service-prod` | `gympt-prod` | `charts/kvs-consumer-service` | `values-prod.yaml` |
| remediation-worker | `remediation-worker-prod` | `gympt-prod` | `charts/remediation-worker` | `values-prod.yaml` |
| report-service | `report-service-prod` | `gympt-prod` | `charts/report-service` | `values-prod.yaml` |

### Dev

| Service | Argo CD App | Namespace | Chart Path | Values File |
| --- | --- | --- | --- | --- |
| backend-api | `backend-api-dev` | `backend-api` | `charts/backend-api` | `values-dev.yaml` |
| agent-service | `agent-service-dev` | `agent-service` | `charts/agent-service` | `values-dev.yaml` |
| posture-analysis-service | `posture-analysis-service-dev` | `posture-analysis` | `charts/posture-analysis-service` | `values-dev.yaml` |
| remediation-worker | `remediation-worker-dev` | `workers` | `charts/remediation-worker` | `values-dev.yaml` |
| report-service | `report-service-dev` | `report-service` | `charts/report-service` | `values-dev.yaml` |

근거:

```text
../gympt-ops/gympt-gitops/argocd/applications/prod/*.yaml
../gympt-ops/gympt-gitops/argocd/applications/dev/*.yaml
```

예: `backend-api-prod`는 `argocd` namespace의 Application이고, source path는 `charts/backend-api`, value file은 `values-prod.yaml`, destination namespace는 `gympt-prod`다.

## 4. 우선 적용 대상

MVP 우선순위는 다음 순서가 적합하다.

| 우선 | Service | 이유 |
| --- | --- | --- |
| 1 | `backend-api` | 기존 PrometheusRule이 가장 구체적이고, 외부 ingress와 ALB/WAF 로그 연결이 있음 |
| 2 | `posture-analysis-service` | GPU/분석 서비스이며 serviceMonitor가 있고 장애 영향 설명이 쉬움 |
| 3 | `agent-service` | AI/agent 도메인과 연결되며 serviceMonitor가 있음 |
| 4 | `report-service` | worker 성격의 비동기 처리 검증 후보 |
| 5 | `kvs-consumer-service` | prod에만 Application이 확인됨 |
| 6 | `remediation-worker` | 기존 자동 조치/rollback 개념과 겹치므로 마지막에 통합 검토 |

## 5. Monitoring 연결값

### Prometheus / Grafana

`kube-prometheus-stack`가 Argo CD Application으로 배포되어 있다.

| 항목 | 값 |
| --- | --- |
| Argo CD App | `kube-prometheus-stack` |
| Namespace | `monitoring` |
| Prometheus internal URL | `http://kube-prometheus-stack-prometheus.monitoring.svc:9090` |
| Grafana host | `grafana.g2mpt.com` |
| Athena datasource DB | `gympt_prod_catalog` |
| Athena workgroup | `gympt-prod-workgroup` |
| Athena result S3 | `s3://gympt-prod-athena-results-337112169365/athena-results/` |

근거:

```text
../gympt-ops/gympt-gitops/argocd/applications/platform/monitoring.yaml
```

### Grafana Dashboard UID

| Dashboard | UID |
| --- | --- |
| API Latency Dashboard | `api-latency` |
| EKS Cluster Overview | `eks-overview` |
| GPU Metrics Dashboard | `gpu-metrics` |
| JVM Metrics Dashboard | `jvm-metrics` |
| Redis Metrics Dashboard | `redis-metrics` |
| SQS Metrics Dashboard | `sqs-metrics` |
| Athena Security Logs | `athena-security-logs` |

근거:

```text
../gympt-ops/gympt-gitops/platform/monitoring/dashboard-*.json
../gympt-ops/gympt-gitops/platform/monitoring/dashboards/dashboard-athena.json
```

## 6. PrometheusRule 연결값

Backend API에 대해 이미 사용 가능한 alert가 있다.

| Alert | Severity | 품질 게이트 적용 |
| --- | --- | --- |
| `BackendHighErrorRate` | critical | CD 실패 |
| `BackendHighLatency` | warning | warning 또는 조건부 실패 |
| `BackendPodRestarting` | warning | warning 또는 조건부 실패 |
| `BackendDBPoolExhaustion` | critical | CD 실패 |
| `BackendHighMemoryUsage` | warning | warning |

근거:

```text
../gympt-ops/gympt-gitops/platform/monitoring/rules/prometheusrule-backend.yaml
../gympt-ops/gympt-gitops/platform/monitoring/prometheusrule-backend.yaml
```

현재 우리 config에 이미 있는 `DBConnectionError`는 실제 `gympt-ops` alert 이름 기준으로 `BackendDBPoolExhaustion`에 맞추는 것이 좋다.

## 7. ServiceMonitor 연결값

| ServiceMonitor | Namespace | app label |
| --- | --- | --- |
| `backend-api` | `backend-api` | `backend-api` |
| `agent-service` | `agent-service` | `agent-service` |
| `posture-analysis-service` | `posture-analysis` | `posture-analysis-service` |
| `remediation-worker` | `workers` | `remediation-worker` |

근거:

```text
../gympt-ops/gympt-gitops/platform/monitoring/servicemonitor-*.yaml
```

정합성 확인:

```text
platform/monitoring/servicemonitor-backend-api.yaml 파일은 namespace backend-api 기준이다.
하지만 charts/backend-api/templates/servicemonitor.yaml은 metadata.namespace: {{ .Release.Namespace }}를 사용한다.
backend-api-prod Argo CD Application destination namespace는 gympt-prod다.
backend-api PrometheusRule도 namespace="gympt-prod"를 조회한다.
따라서 backend-api-prod Quality Gate는 gympt-prod 기준으로 평가한다.
```

## 8. Image Tag 업데이트 연결값

GitOps image tag 변경 대상은 각 chart의 values 파일이다.

예시:

```text
../gympt-ops/gympt-gitops/charts/backend-api/values-prod.yaml
../gympt-ops/gympt-gitops/charts/backend-api/values-dev.yaml
```

Prod ECR repository 예시:

| Service | Prod ECR Repository |
| --- | --- |
| backend-api | `337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/backend-api` |
| agent-service | `337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/agent-service` |
| posture-analysis-service | `337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/posture-analysis-service` |
| kvs-consumer-service | `337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/kvs-consumer-service` |
| remediation-worker | `337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/remediation-worker` |
| report-service | `337112169365.dkr.ecr.ap-northeast-2.amazonaws.com/gympt-prod/report-service` |

Dev ECR repository는 같은 계정/리전에서 `gympt-dev/{service}` 패턴이다.

## 9. Slack 연결값

Alertmanager Slack 알림은 `monitoring/alertmanager-slack-webhook` Secret의 `url` key를 사용한다.

채널:

```text
#alerts
#alerts-warning
#alerts-critical
```

근거:

```text
../gympt-ops/gympt-gitops/argocd/applications/platform/monitoring.yaml
../gympt-ops/gympt-gitops/platform/external-secrets/external-secret-alertmanager-slack.yaml
```

우리 CD Quality Gate 1차 알림은 기존 Alertmanager 경로와 중복될 수 있으므로, 적용 전 별도 채널을 둘지 기존 채널을 쓸지 결정해야 한다.

## 10. Athena / S3 Logs 연결값

현재 확인된 값:

```text
Athena database: gympt_prod_catalog
Athena workgroup: gympt-prod-workgroup
Athena outputLocation: s3://gympt-prod-athena-results-337112169365/athena-results/
ALB access log bucket: gympt-prod-logs-337112169365
ALB access log prefix: alb-access-logs
```

근거:

```text
../gympt-ops/gympt-gitops/argocd/applications/platform/monitoring.yaml
../gympt-ops/gympt-gitops/charts/backend-api/values-prod.yaml
../gympt-ops/gympt-gitops/charts/posture-analysis-service/values-prod.yaml
../gympt-ops/gympt-infra/terraform/README.md
```

## 11. 우리 쪽 config 반영 후보

우선 `backend-api` prod 기준으로 다음 값을 맞춘다.

```yaml
service: backend-api
environment: prod
namespace: gympt-prod
deployment: backend-api-prod
argocdApp: backend-api-prod
chartPath: charts/backend-api
valuesFile: values-prod.yaml
prometheusUrl: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
grafanaBaseUrl: https://grafana.g2mpt.com
dashboardUids:
  apiLatency: api-latency
  jvmMetrics: jvm-metrics
  eksOverview: eks-overview
  athenaSecurityLogs: athena-security-logs
qualityGateAlerts:
  - BackendHighErrorRate
  - BackendHighLatency
  - BackendPodRestarting
  - BackendDBPoolExhaustion
  - BackendHighMemoryUsage
```

## 12. 적용 전 확인 필요

아직 확정하지 말아야 할 값:

```text
실제 GitHub Actions workflow가 어느 repository에서 실행될지
PROMETHEUS_URL을 cluster 내부 URL로 쓸지 외부 접근 URL로 쓸지
Lambda/Athena 분석 파이프라인을 prod부터 붙일지 dev부터 붙일지
```

확정한 값:

```text
Slack 채널은 신규 #cd-deploy-alarm 사용
EventBridge는 개인 파트 전용 cd-quality-gate-prod-bus 사용
Infra는 Terraform으로 관리
backend-api-prod Quality Gate namespace는 gympt-prod 사용
```
