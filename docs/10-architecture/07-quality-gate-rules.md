# DOC-07. Quality Gate Rules

## 1. 배포 검증 기준

CD Quality Gate는 Kubernetes rollout만 확인하지 않고, 배포 직후 서비스 메트릭을 확인한다.

기본 검증 window는 다음과 같이 둔다.

```text
Health Check Window: 배포 직후 5분
Log Analysis Window: 배포 실패 전후 10~15분
```

## 2. Backend API 기준

```text
HTTP 5xx Error Rate > 5%
p95 Latency > 2s
Pod Restart 증가
Unavailable Replicas > 0
Readiness Probe Failure 발생
DB Connection Error 증가
```

## 3. Posture Analysis Service 기준

```text
WebSocket 연결 실패 증가
GPU Utilization 비정상 증가 또는 0 유지
Inference Latency 증가
Pod Restart 증가
Frame Processing Error 증가
SQS Queue Backlog 증가
```

## 4. Worker/Lambda 기준

```text
SQS ApproximateAgeOfOldestMessage 증가
DLQ Message 증가
Lambda Error 증가
Lambda Duration 증가
Timeout 증가
Retry 증가
```

## 5. Infra/Security 기준

```text
WAF Blocked Request 증가
CloudFront 5xx 증가
ALB Target 5xx 증가
Inspector Finding 증가
S3 Access Denied 증가
```

## 5.1 현재 PrometheusRule 연동 기준

`gympt-ops/gympt-gitops/platform/monitoring`을 readonly reference로 보고, 현재 Quality Gate는 아래 alert를 5분 Health Check Window에서 함께 평가한다.

Backend:

```text
BackendHighErrorRate
BackendHighLatency
BackendPodRestarting
BackendDBPoolExhaustion
BackendHighMemoryUsage
```

Kubernetes / SQS:

```text
NodeHighCPUUsage
PodRestartFrequent
SQSQueueBacklog
SQSMessageAge
SQSDLQMessages
```

GPU / Redis / Bedrock:

```text
GPUHighUtilization
GPUMemoryHigh
RedisConnectionError
RedisHighMemory
RedisHighEvictionRate
BedrockHighErrorRate
BedrockThrottling
```

연관 namespace:

```text
gympt-prod
monitoring
posture-analysis
elasticache
```

Slack 1차 알림에는 아래 Grafana dashboard 링크를 함께 넣는다.

```text
api-latency
eks-overview
jvm-metrics
gpu-metrics
redis-metrics
sqs-metrics
```

## 6. 대응 판단 기준

### Rollback 권장 상황

```text
배포 직후 5xx Error Rate 급증
새 버전에서만 Pod Restart 발생
특정 API 장애가 새 배포 이후 시작됨
p95 Latency가 배포 직후 급증
이전 버전에서는 동일 문제가 없었음
```

대응:

```text
Argo CD rollback
또는 GitOps Repository의 image tag를 이전 버전으로 복구
```

### Manual Fix 권장 상황

```text
환경 변수 누락
Secret 값 누락
DB Migration 문제
특정 API 로직 오류
외부 API 호출 timeout 설정 문제
```

대응:

```text
담당자가 코드 또는 설정 수정
새 image build
재배포
재검증
```

### DR 승인 권장 상황

```text
DB 장애
Redis 장애
EKS Node 대규모 장애
ALB 장애
CloudFront/WAF 대규모 장애
AWS 리전 장애
```

대응:

```text
관리자 승인 후 DR Runbook 실행
트래픽 우회
서비스 축소 운영
백업 복구
인프라 재생성
```
