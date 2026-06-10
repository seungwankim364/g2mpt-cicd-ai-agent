# DOC-21. Terraform Infra Design

## 1. 목적

CD Quality Gate와 AI Incident Analysis Pipeline에 필요한 AWS 리소스를 Terraform으로 관리하기 위한 설계를 정의한다.

## 2. 관리 대상 리소스

```text
EventBridge custom event bus/rule
Lambda analysis orchestrator
IAM roles and policies
S3 result bucket
Athena database and workgroup
CloudWatch log groups
Secrets Manager secrets
```

GitHub Actions workflow 자체와 Prometheus/Grafana dashboard는 이 문서의 Terraform 범위에 포함하지 않는다.

## 3. Terraform 디렉터리 구조

```text
infra/
  terraform/
    main.tf
    variables.tf
    outputs.tf
    providers.tf
    eventbridge.tf
    lambda.tf
    iam.tf
    s3.tf
    athena.tf
    secrets.tf
    cloudwatch.tf
    env/
      dev.tfvars
      prod.tfvars
```

## 4. EventBridge

리소스:

```text
aws_cloudwatch_event_bus.cd_quality_gate
aws_cloudwatch_event_rule.deployment_failed
aws_cloudwatch_event_target.analysis_orchestrator
aws_lambda_permission.allow_eventbridge
```

Event pattern:

```json
{
  "source": ["cd.quality-gate"],
  "detail-type": ["DeploymentFailed"]
}
```

## 5. Lambda

리소스:

```text
aws_lambda_function.analysis_orchestrator
aws_cloudwatch_log_group.analysis_orchestrator
aws_iam_role.analysis_orchestrator
aws_iam_role_policy.analysis_orchestrator
```

권장 설정:

```text
runtime: python3.12
timeout: 300 seconds
memory_size: 512 MB
reserved_concurrent_executions: 5
```

환경 변수:

```text
RESULT_BUCKET
ATHENA_DATABASE
ATHENA_WORKGROUP
ATHENA_OUTPUT_LOCATION
AI_AGENT_ENDPOINT
QUERY_TEMPLATE_PREFIX
```

## 6. S3

리소스:

```text
aws_s3_bucket.analysis_results
aws_s3_bucket_versioning.analysis_results
aws_s3_bucket_server_side_encryption_configuration.analysis_results
aws_s3_bucket_lifecycle_configuration.analysis_results
aws_s3_bucket_public_access_block.analysis_results
```

저장 경로:

```text
deployment-failures/{environment}/{service}/{deploymentId}/
athena-results/
```

Lifecycle:

```text
raw query result: 30 days
summary JSON: 180 days
status marker: 180 days
```

## 7. Athena

리소스:

```text
aws_athena_database.logs
aws_athena_workgroup.cd_quality_gate
```

Workgroup 설정:

```text
enforce_workgroup_configuration = true
publish_cloudwatch_metrics_enabled = true
result_configuration.output_location = s3://.../athena-results/
```

로그 table schema는 별도 SQL 파일로 관리하고, Terraform에서는 database와 workgroup 중심으로 관리한다.

## 8. IAM 정책

Lambda에 필요한 권한:

```text
events:PutEvents
athena:StartQueryExecution
athena:GetQueryExecution
athena:GetQueryResults
glue:GetDatabase
glue:GetTable
s3:GetObject
s3:PutObject
s3:ListBucket
secretsmanager:GetSecretValue
logs:CreateLogStream
logs:PutLogEvents
```

권한은 result bucket, Athena workgroup, 필요한 Glue database/table로 제한한다.

## 9. Secrets Manager

관리할 secret:

```text
cd-quality-gate/slack/webhook-url
cd-quality-gate/ai-agent/api-key
```

Secret 값은 Terraform state에 평문으로 저장하지 않는다. Terraform은 secret container만 생성하고, 실제 값은 배포 후 별도 주입한다.

## 10. CloudWatch Logs

Log group:

```text
/aws/lambda/cd-quality-gate-analysis-orchestrator
```

Retention:

```text
dev: 14 days
prod: 90 days
```

## 11. Output

Terraform output:

```text
event_bus_name
event_bus_arn
lambda_function_name
lambda_function_arn
result_bucket_name
athena_database_name
athena_workgroup_name
```

GitHub Actions는 `event_bus_name` 또는 `event_bus_arn`을 사용해 배포 실패 이벤트를 발행한다.

## 12. 환경 분리

환경별로 다음 값을 분리한다.

```text
aws_region
environment
result_bucket_name
athena_database_name
athena_workgroup_name
lambda_reserved_concurrency
log_retention_days
```

`dev`와 `prod`는 같은 state를 공유하지 않는다.

## 13. 검증 기준

```text
terraform fmt 통과
terraform validate 통과
dev tfvars로 plan 생성 가능
EventBridge rule이 Lambda target을 가짐
Lambda role이 필요한 최소 권한만 포함
S3 bucket public access가 차단됨
Athena workgroup result location이 설정됨
```

