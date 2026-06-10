# DOC-19. Athena Log Analysis Design

## 1. 목적

배포 실패 시점 전후의 로그를 Athena로 분석하기 위한 query, schema, summary 생성 규칙을 정의한다.

Athena 분석은 AI Agent가 원인 후보를 만들 수 있도록 구조화된 증거를 제공하는 역할을 한다.

## 2. 분석 대상 로그

```text
ALB access logs
CloudFront access logs
AWS WAF logs
Application logs
Kubernetes event logs
Lambda logs
```

MVP에서는 ALB access logs, WAF logs, Application logs를 우선 대상으로 한다.

## 3. 분석 시간 범위

기본 분석 범위:

```text
failedAt - 10 minutes
failedAt + 5 minutes
```

비교 기준 범위:

```text
failedAt - 70 minutes
failedAt - 55 minutes
```

비교 기준 범위는 배포 전 정상 상태와 실패 시점의 차이를 확인하기 위해 사용한다.

## 4. Query Template 구조

서비스별 query template은 어떤 SQL을 실행할지 정의한다.

```json
{
  "service": "backend-api",
  "environment": "prod",
  "windowMinutesBefore": 10,
  "windowMinutesAfter": 5,
  "baselineMinutesBefore": 70,
  "baselineWindowMinutes": 15,
  "queries": [
    {
      "id": "alb-5xx-errors",
      "file": "alb-5xx-errors.sql",
      "required": true
    },
    {
      "id": "api-latency-top-paths",
      "file": "api-latency-top-paths.sql",
      "required": false
    },
    {
      "id": "application-error-patterns",
      "file": "application-error-patterns.sql",
      "required": true
    }
  ]
}
```

## 5. SQL Parameter

모든 SQL은 공통 parameter를 받는다.

```text
service
environment
start_time
end_time
baseline_start_time
baseline_end_time
deployment_id
commit_sha
image_tag
```

SQL parameter는 문자열 치환이 아니라 안전한 template rendering 규칙으로 관리한다.

## 6. Query 목록

### 6.1 `alb-5xx-errors.sql`

목적:

```text
배포 실패 시간대에 증가한 ALB 5xx 응답을 path, target, status_code 기준으로 집계
```

출력:

```text
path
target_group
target_ip
elb_status_code
target_status_code
count
sample_trace_id
```

### 6.2 `api-latency-top-paths.sql`

목적:

```text
응답 시간이 급증한 API path 확인
```

출력:

```text
path
p50_latency_ms
p95_latency_ms
p99_latency_ms
request_count
```

### 6.3 `application-error-patterns.sql`

목적:

```text
Application log에서 exception, timeout, connection error 패턴 집계
```

출력:

```text
error_pattern
exception_class
count
first_seen
last_seen
sample_message
```

### 6.4 `waf-blocked-requests.sql`

목적:

```text
WAF blocked request 증가 여부와 rule group 확인
```

출력:

```text
rule_id
terminating_rule_id
client_ip
country
uri
count
```

### 6.5 `cloudfront-5xx-errors.sql`

목적:

```text
Edge 레벨 5xx 또는 origin fetch 실패 확인
```

출력:

```text
distribution_id
uri
status
edge_result_type
origin_fbl_ms
count
```

## 7. Summary JSON 구조

Athena 결과는 AI Agent가 읽기 쉬운 summary JSON으로 변환한다.

```json
{
  "deploymentId": "deploy-20260609-001",
  "service": "backend-api",
  "environment": "prod",
  "failedAt": "2026-06-09T08:20:00Z",
  "analysisWindow": {
    "start": "2026-06-09T08:10:00Z",
    "end": "2026-06-09T08:25:00Z"
  },
  "signals": [
    {
      "name": "alb_5xx_spike",
      "severity": "critical",
      "summary": "ALB target 5xx increased on /api/v1/orders",
      "evidence": {
        "count": 320,
        "topPath": "/api/v1/orders",
        "targetStatusCode": "500"
      }
    }
  ],
  "queryResults": [
    {
      "id": "alb-5xx-errors",
      "status": "succeeded",
      "s3Path": "s3://cd-quality-gate-results/..."
    }
  ]
}
```

## 8. Severity Mapping

| 조건 | Severity |
| --- | --- |
| 5xx가 baseline 대비 3배 이상 증가 | critical |
| p95 latency가 threshold 2배 이상 | critical |
| 특정 error pattern이 50건 이상 | warning |
| WAF block 증가가 배포 변경과 직접 관련 없음 | info |

## 9. AI Agent에 전달할 Evidence

AI Agent에는 원문 로그 전체가 아니라 요약된 evidence만 전달한다.

```text
top affected paths
top exception classes
top status codes
time series spike summary
sample trace id
query result S3 links
```

민감 정보가 포함될 수 있는 request body, authorization header, cookie 값은 전달하지 않는다.

## 10. MVP Query Set

MVP에서 반드시 구현할 query:

```text
alb-5xx-errors.sql
application-error-patterns.sql
waf-blocked-requests.sql
```

추가 구현 후보:

```text
api-latency-top-paths.sql
cloudfront-5xx-errors.sql
queue-processing-delay.sql
```

## 11. 검증 기준

```text
sample EventBridge event로 query parameter가 올바르게 생성됨
Athena query가 지정된 workgroup에서 실행됨
query result가 S3에 저장됨
summary JSON이 schema validation을 통과함
AI Agent가 summary JSON을 읽어 원인 후보를 생성할 수 있음
```

