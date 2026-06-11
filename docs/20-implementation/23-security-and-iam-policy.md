# DOC-23. Security and IAM Policy

## 1. 목적

CD Quality Gate와 AI Incident Analysis Pipeline에서 필요한 권한, secret, 로그 보안 기준을 정의한다.

## 2. 보안 원칙

```text
최소 권한
환경별 권한 분리
민감 정보 로그 출력 금지
자동 조치는 운영자 승인 후 실행
AI Agent에는 필요한 evidence만 전달
```

## 3. GitHub Actions 권한

GitHub Actions는 배포와 Quality Gate 실행에 필요한 권한만 가진다.

필요 권한:

```text
ECR image push
GitOps repository update
Kubernetes rollout read
Prometheus API read
EventBridge PutEvents
Slack webhook send
```

AWS 연동은 장기 access key보다 OIDC federation을 권장한다.

## 4. Lambda 권한

Lambda Orchestrator 권한:

```text
athena:StartQueryExecution
athena:GetQueryExecution
athena:GetQueryResults
glue:GetDatabase
glue:GetTable
s3:GetObject
s3:PutObject
s3:ListBucket
secretsmanager:GetSecretValue
logs:PutLogEvents
```

제한 기준:

```text
S3는 분석 결과 bucket과 로그 bucket read 범위로 제한
Athena는 지정 workgroup만 허용
Secrets Manager는 필요한 secret ARN만 허용
Glue는 필요한 database/table만 허용
```

## 5. S3 보안

```text
public access block 활성화
server-side encryption 활성화
bucket versioning 활성화
raw query result lifecycle 설정
cross-account 접근 금지 또는 명시적 allowlist
```

분석 결과에는 민감 정보가 포함될 수 있으므로 외부 공유 링크를 생성하지 않는다.

## 6. Slack Webhook

Slack webhook은 secret으로 관리한다.

주의사항:

```text
repository에 평문 저장 금지
workflow log에 출력 금지
Lambda environment variable에 평문 직접 저장 지양
rotation 절차 문서화
```

Slack 메시지에는 다음 정보를 포함하지 않는다.

```text
Authorization header
cookie
access token
customer personal data
request body 원문
database connection string
```

## 7. AI Agent 보안

AI Agent 입력은 최소화된 evidence만 포함한다.

허용:

```text
alert name
metric value
error pattern summary
top path
status code
sample trace id
S3 result path
```

비허용:

```text
전체 로그 원문
개인정보
secret 값
인증 header
결제/계정 데이터
```

AI Agent 출력은 자동 실행 명령으로 사용하지 않는다. 모든 조치는 승인 workflow를 거친다.

## 8. Approval Policy

자동 실행 금지 대상:

```text
rollback
traffic shift
DR failover
database migration rollback
runbook command execution
```

위 작업은 Slack approval 또는 별도 운영 승인 이후 실행한다.

## 9. Audit Trail

남겨야 하는 기록:

```text
DeploymentFailed event
Quality Gate decision
Athena query execution id
AI Agent recommendation
Slack approval user
approved action
action result
```

저장 위치:

```text
S3 deployment-failures path
CloudWatch Logs
GitHub Actions run log
Slack workflow audit
```

## 10. IAM Policy 검토 기준

```text
Resource "*" 사용 최소화
Action "*" 금지
production 권한과 development 권한 분리
secret 접근은 ARN 단위 제한
S3 write는 결과 prefix로 제한
Athena workgroup 강제 사용
```

## 11. 운영 체크리스트

```text
Slack webhook secret rotation 가능
GitHub Actions OIDC role trust policy 검토
Lambda role 최소 권한 검토
S3 bucket public access 차단 확인
Athena query result bucket 암호화 확인
AI Agent 입력에 민감 정보가 없는지 fixture로 검증
```
