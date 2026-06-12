# DOC-18. Lambda Analysis Orchestrator Design

## 1. 목적

배포 실패 이벤트가 발생했을 때 분석 파이프라인을 시작하는 Lambda Orchestrator를 설계한다.

이 Lambda는 EventBridge에서 `DeploymentFailed` 이벤트를 수신하고, Athena 로그 분석을 실행한 뒤, 분석 결과를 S3에 저장하고 Amazon Bedrock 기반 AI 분석과 Slack 알림으로 연결한다.

## 2. 역할

```text
EventBridge event validation
Athena query orchestration
Analysis summary generation
S3 result persistence
Amazon Bedrock invocation
Slack 2nd alert trigger
```

Lambda는 장애 분석의 중심 실행자이지만, 원인 판단 자체를 직접 수행하지 않는다. 원인 판단은 Athena summary와 Runbook을 입력받은 Bedrock 모델이 담당하고, Bedrock이 비활성화되거나 실패하면 local `ai-agent` rule analyzer로 fallback한다.

## 3. 입력 이벤트

입력은 EventBridge의 `DeploymentFailed` 이벤트다.

필수 필드:

```text
service
environment
deploymentId
repository
commitSha
imageTag
argocdApp
failedAt
alerts
grafanaLinks
prometheusUrl
argocdUrl
```

예시:

```json
{
  "source": "cd.quality-gate",
  "detail-type": "DeploymentFailed",
  "detail": {
    "service": "backend-api",
    "environment": "prod",
    "deploymentId": "deploy-20260609-001",
    "commitSha": "abc1234",
    "imageTag": "backend-api:abc1234",
    "argocdApp": "backend-api-prod",
    "failedAt": "2026-06-09T08:20:00Z",
    "alerts": [
      {
        "alertName": "BackendHighErrorRate",
        "severity": "critical",
        "value": "8.2"
      }
    ]
  }
}
```

## 4. 실행 흐름

```text
1. EventBridge event 수신
2. detail 필드 검증
3. deploymentId 기준 idempotency 확인
4. 서비스별 Athena query template 로딩
5. 실패 시각 기준 분석 시간 범위 계산
6. Athena StartQueryExecution 실행
7. QueryExecutionId 목록 저장
8. Athena 결과 수집 또는 pending 상태 저장
9. summary JSON 생성
10. S3 deployment-failures 경로에 저장
11. Bedrock AI 분석 호출
12. Slack 2차 알림 전송
```

## 5. 주요 함수

```text
handler(event, context)
validate_event(event)
build_analysis_context(detail)
load_query_template(service, environment)
start_athena_queries(context, template)
collect_athena_results(query_execution_ids)
build_athena_summary(context, query_results)
write_summary_to_s3(summary)
invoke_ai_agent(summary)
bedrock_agent.analyze_with_bedrock(summary)
send_second_slack_alert(ai_result)
```

## 6. Idempotency 기준

같은 배포 실패 이벤트가 재전달될 수 있으므로 `deploymentId`를 기준으로 중복 실행을 방지한다.

권장 방식:

```text
S3 marker object
DynamoDB idempotency table
Lambda Powertools idempotency utility
```

MVP에서는 S3 marker object를 사용한다.

```text
s3://cd-quality-gate-results/deployment-failures/{environment}/{service}/{deploymentId}/status.json
```

이미 `status`가 `completed`이면 재실행하지 않는다. `failed` 또는 `partial`이면 수동 재처리 대상으로 둔다.

## 7. Athena 실행 정책

Athena query는 서비스별 template에 정의된 목록만 실행한다.

```text
backend-api
  -> alb-5xx-errors.sql
  -> api-latency-top-paths.sql
  -> application-error-patterns.sql

edge
  -> cloudfront-5xx-errors.sql
  -> waf-blocked-requests.sql

worker
  -> application-error-patterns.sql
  -> queue-processing-delay.sql
```

분석 시간 범위:

```text
startTime = failedAt - 10 minutes
endTime = failedAt + 5 minutes
```

서비스 특성에 따라 window는 template에서 override할 수 있다.

## 8. 출력 S3 구조

```text
s3://cd-quality-gate-results/
  deployment-failures/
    prod/
      backend-api/
        deploy-20260609-001/
          event.json
          athena-summary.json
          ai-recommendation.json
          status.json
          queries/
            alb-5xx-errors.json
            api-latency-top-paths.json
```

## 9. 상태 모델

```text
received
athena_running
athena_completed
ai_running
completed
partial
failed
```

`partial`은 Athena query 일부가 실패했지만 AI Agent 호출이 가능한 수준의 데이터가 있는 상태다.

## 10. 실패 처리

| 실패 지점 | 처리 |
| --- | --- |
| 이벤트 schema 오류 | Slack에 분석 불가 알림, status failed |
| Athena query 시작 실패 | 재시도 후 failed |
| Athena query timeout | partial summary 생성 |
| S3 저장 실패 | Lambda error 발생, 재시도 유도 |
| Bedrock 호출 실패 | local ai-agent fallback으로 분석 후 Slack 전송 |
| Slack 2차 알림 실패 | status completed_with_notification_error |

## 11. Timeout 기준

권장 timeout:

```text
Lambda timeout: 5 minutes
Athena query wait: 2 minutes
Bedrock call timeout: Lambda/boto3 client timeout 기준
```

Athena query가 길어질 경우 Lambda 한 번에서 모두 기다리지 않고, Step Functions 또는 재호출 방식으로 분리할 수 있다.

MVP에서는 짧은 query만 실행하고 Lambda 내부에서 결과를 수집한다.

## 12. 환경 변수

```text
RESULT_BUCKET
ATHENA_DATABASE
ATHENA_WORKGROUP
ATHENA_OUTPUT_LOCATION
AI_AGENT_ENDPOINT
BEDROCK_ENABLED
BEDROCK_MODEL_ID
BEDROCK_REGION
BEDROCK_MAX_TOKENS
SLACK_WEBHOOK_URL
QUERY_TEMPLATE_PREFIX
```

Slack webhook은 AWS Secrets Manager에 저장한다. Bedrock은 API key가 아니라 Lambda IAM role의 `bedrock:InvokeModel` 권한과 AWS 계정의 model access 설정을 사용한다.

## 13. 관측 지표

Lambda 자체도 운영 지표를 남겨야 한다.

```text
orchestrator.invocations
orchestrator.failures
orchestrator.athena_query_count
orchestrator.athena_failed_query_count
orchestrator.ai_agent_failures
orchestrator.analysis_duration_seconds
```

## 14. 구현 시 주의점

```text
EventBridge event는 반드시 schema validation 후 처리
Athena SQL에 사용자 입력 직접 결합 금지
S3 경로는 deploymentId 기준으로 deterministic하게 생성
Slack에는 민감한 로그 원문을 직접 포함하지 않음
AI Agent 실패가 전체 분석 실패로 이어지지 않도록 분리
```
