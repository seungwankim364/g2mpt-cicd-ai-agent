# DOC-16. Prometheus Rule and Query Examples

## 1. 목적

이 문서는 CD Quality Gate에서 사용할 Prometheus alert와 PromQL query 예시를 정리한다.

핵심은 배포 직후 서비스 품질 저하를 자동으로 판단할 수 있는 metric을 정의하는 것이다.

## 2. Quality Gate 기본 원칙

Quality Gate는 다음 두 가지를 함께 본다.

```text
1. PrometheusRule 기반 firing alert
2. 배포 직후 window의 주요 metric query 결과
```

초기 MVP에서는 `/api/v1/alerts`로 firing alert를 확인하는 방식이 가장 단순하다.

이후 고도화 단계에서 `/api/v1/query`와 `/api/v1/query_range`를 사용해 metric 값을 직접 판단한다.

## 3. 공통 라벨 기준

Prometheus metric과 alert에는 서비스 식별을 위한 label이 있어야 한다.

권장 label:

```text
service
namespace
environment
deployment
pod
container
route
status
```

예시:

```text
service="backend-api"
namespace="prod"
environment="prod"
deployment="backend-api"
```

## 4. Backend API Query

### 4.1 HTTP 5xx Error Rate

```promql
sum(rate(http_requests_total{service="backend-api", status=~"5.."}[5m]))
/
sum(rate(http_requests_total{service="backend-api"}[5m]))
* 100
```

실패 기준:

```text
5xx Error Rate > 5%
```

Alert 이름:

```text
BackendHighErrorRate
```

### 4.2 p95 Latency

```promql
histogram_quantile(
  0.95,
  sum(rate(http_request_duration_seconds_bucket{service="backend-api"}[5m])) by (le)
)
```

실패 기준:

```text
p95 Latency > 2s
```

Alert 이름:

```text
BackendHighLatency
```

### 4.3 DB Connection Error

metric이 애플리케이션에서 노출되는 경우:

```promql
sum(rate(db_connection_errors_total{service="backend-api"}[5m]))
```

실패 기준:

```text
DB Connection Error 증가
```

Alert 이름:

```text
BackendDBConnectionError
```

## 5. Kubernetes Query

### 5.1 Pod Restart 증가

```promql
increase(kube_pod_container_status_restarts_total{namespace="prod", pod=~"backend-api-.*"}[5m])
```

실패 기준:

```text
Pod Restart 증가 > 0
```

Alert 이름:

```text
BackendPodRestarting
```

### 5.2 Deployment Unavailable Replicas

```promql
kube_deployment_status_replicas_unavailable{namespace="prod", deployment="backend-api"}
```

실패 기준:

```text
Unavailable Replicas > 0
```

Alert 이름:

```text
BackendDeploymentUnavailable
```

### 5.3 Readiness Probe Failure

환경에 따라 metric 이름이 다를 수 있다. kube-state-metrics와 kubelet metric 구성을 확인해야 한다.

예시:

```promql
sum(rate(prober_probe_total{namespace="prod", pod=~"backend-api-.*", result="failed"}[5m]))
```

실패 기준:

```text
Readiness/Liveness Probe Failure 증가
```

## 6. Worker / Lambda Query

### 6.1 SQS Oldest Message Age

```promql
aws_sqs_approximate_age_of_oldest_message_average{queue_name="recommendation-update"}
```

실패 기준:

```text
ApproximateAgeOfOldestMessage 증가
```

### 6.2 DLQ Message 증가

```promql
increase(aws_sqs_approximate_number_of_messages_visible_sum{queue_name=~".*dlq.*"}[5m])
```

### 6.3 Lambda Error

```promql
sum(rate(aws_lambda_errors_sum{function_name="recommendation-worker"}[5m]))
```

## 7. Infra / Security Query

### 7.1 ALB Target 5xx

```promql
sum(rate(aws_applicationelb_httpcode_target_5_xx_count_sum{load_balancer=~".*prod.*"}[5m]))
```

### 7.2 CloudFront 5xx

```promql
sum(rate(aws_cloudfront_5xx_error_rate_average{distribution_id="DISTRIBUTION_ID"}[5m]))
```

### 7.3 WAF Blocked Request 증가

```promql
sum(rate(aws_wafv2_blocked_requests_sum{web_acl="prod-web-acl"}[5m]))
```

## 8. PrometheusRule 예시

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backend-api-quality-gate-rules
  namespace: monitoring
spec:
  groups:
    - name: backend-api.quality-gate
      rules:
        - alert: BackendHighErrorRate
          expr: |
            (
              sum(rate(http_requests_total{service="backend-api", status=~"5.."}[5m]))
              /
              sum(rate(http_requests_total{service="backend-api"}[5m]))
            ) * 100 > 5
          for: 2m
          labels:
            severity: critical
            service: backend-api
            quality_gate: "true"
          annotations:
            summary: "Backend API 5xx error rate is high after deployment"

        - alert: BackendHighLatency
          expr: |
            histogram_quantile(
              0.95,
              sum(rate(http_request_duration_seconds_bucket{service="backend-api"}[5m])) by (le)
            ) > 2
          for: 2m
          labels:
            severity: warning
            service: backend-api
            quality_gate: "true"
          annotations:
            summary: "Backend API p95 latency is high after deployment"
```

## 9. Quality Gate Alert Filtering

GitHub Actions에서 모든 alert를 실패로 보지 않고, `quality_gate="true"` label이 있는 alert만 볼 수 있다.

필터링 기준:

```text
status.state == "firing"
labels.quality_gate == "true"
labels.service == SERVICE_NAME
labels.environment == ENVIRONMENT
```

## 10. API 호출 예시

### Alerts

```bash
curl -s "$PROMETHEUS_URL/api/v1/alerts"
```

### Instant Query

```bash
curl -G "$PROMETHEUS_URL/api/v1/query" \
  --data-urlencode 'query=sum(rate(http_requests_total{service="backend-api",status=~"5.."}[5m]))'
```

### Range Query

```bash
curl -G "$PROMETHEUS_URL/api/v1/query_range" \
  --data-urlencode 'query=histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="backend-api"}[5m])) by (le))' \
  --data-urlencode 'start=2026-06-08T15:10:00+09:00' \
  --data-urlencode 'end=2026-06-08T15:20:00+09:00' \
  --data-urlencode 'step=30s'
```

## 11. MVP 추천 Query Set

MVP에서는 다음 5개만 먼저 적용해도 충분하다.

```text
BackendHighErrorRate
BackendHighLatency
BackendPodRestarting
BackendDeploymentUnavailable
BackendDBConnectionError
```

이후 서비스별로 SQS, Redis, GPU, WAF, CloudFront 지표를 확장한다.
