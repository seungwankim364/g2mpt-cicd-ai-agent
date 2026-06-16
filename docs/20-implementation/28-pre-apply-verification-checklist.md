# DOC-33. Pre-Apply Verification Checklist

이 문서는 AWS 리소스를 다시 올리기 전에 로컬 파일만으로 확인 가능한 항목을 정리한다.

## 1. Terraform apply/destroy 순서

Terraform apply 전에 Lambda zip을 먼저 만든다.

```bash
scripts/lambda/package-analysis-orchestrator.sh
```

그 다음 Terraform을 실행한다.

```bash
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform fmt -check
terraform -chdir=infra/terraform validate
terraform -chdir=infra/terraform plan -out=tfplan
terraform -chdir=infra/terraform apply tfplan
```

Dashboard AWS 리소스는 기본 비활성화 상태다.

```bash
terraform -chdir=infra/terraform plan -var enable_dashboard=true -out=tfplan-dashboard
```

Dashboard를 켜면 추가되는 리소스:

```text
S3 dashboard static bucket
CloudFront dashboard distribution
CloudFront /api/* -> API Gateway routing
API Gateway dashboard API
Lambda dashboard-api
DynamoDB dashboard action table
IAM role/policy
S3 dashboard object uploads
```

기본 plan은 dashboard를 만들지 않는다.

```text
enable_dashboard=false -> dashboard resources disabled
enable_dashboard=true  -> dashboard resources enabled
```

Slack webhook secret은 이미 수동 생성된 값을 재사용한다.

```text
terraform.tfvars:
  slack_webhook_secret_arn = arn:aws:secretsmanager:ap-northeast-2:337112169365:secret:cd-quality-gate-prod/slack/webhook-url-SjqVIF
```

이 값이 비어 있으면 Terraform이 `cd-quality-gate-prod/slack/webhook-url` secret을 새로 만들려고 한다.
이미 같은 이름의 secret이 있으면 apply가 실패하므로, 운영 계정에서는 기존 ARN을 유지한다.

생성 후 확인할 output:

```text
event_bus_name
lambda_function_name
result_bucket_name
athena_database_name
athena_workgroup_name
slack_interactivity_url
dashboard_cloudfront_url
dashboard_api_url
```

퇴근 전 비용 정리는 stop이 아니라 Terraform destroy 기준이다.

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
scripts/aws/destroy-terraform-stack.sh
```

실제 삭제:

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
ALLOW_PROD=true \
scripts/aws/destroy-terraform-stack.sh --execute
```

보존 대상:

```text
cd-quality-gate-prod/slack/webhook-url
cd-quality-gate/github/dispatch-token
cd-quality-gate/slack/signing-secret
gympt-ops 리소스 전체
```

## 2. GitHub workflow dispatch 확인

`lambda/deployment-action-executor/app.py`가 승인 action type별로 아래 workflow를 dispatch한다.

| Action type | Repository variable | Workflow file | Local file exists |
| --- | --- | --- | --- |
| `rollback` | `rollback_workflow_repo` | `rollback.yml` | yes |
| `manual_fix` | `manual_fix_workflow_repo` | `manual-fix.yml` | yes |
| `change` | `change_workflow_repo` | `change-apply.yml` | yes |
| `restart_deployment` | `change_workflow_repo` | `change-apply.yml` | yes |
| `scale_replicas` | `change_workflow_repo` | `change-apply.yml` | yes |
| `increase_memory` | `change_workflow_repo` | `change-apply.yml` | yes |
| `increase_hpa` | `change_workflow_repo` | `change-apply.yml` | yes |
| `open_fix_issue` | `manual_fix_workflow_repo` | `manual-fix.yml` | yes |
| `open_change_pr` | `change_workflow_repo` | `change-apply.yml` | yes |

현재 기본 repository:

```text
rollback/manual_fix/change -> seungwankim364/g2mpt-cicd-ai-agent
app redeploy -> hj-3/gympt-app
```

dispatch input 이름은 아래 파일 사이에서 일치한다.

```text
lambda/deployment-action-executor/app.py
.github/workflows/rollback.yml
.github/workflows/manual-fix.yml
.github/workflows/change-apply.yml
```

공통 input:

```text
deployment_id
service
environment
action_type
approved_by
reason
current_image_tag
target_image_tag
app_repo
app_workflow
app_ref
```

주의:

```text
rollback은 target_image_tag가 필수다.
rollback은 이 repo의 `.github/workflows/rollback.yml`이 `hj-3/gympt-gitops/charts/backend-api/values-prod.yaml`의 `image.tag`를 직접 이전 tag로 갱신한다.
따라서 이 repo의 GitHub Secret `GH_WORKFLOW_DISPATCH_TOKEN`은 `hj-3/gympt-gitops` contents write 권한이 필요하다.
AWS Secrets Manager의 GitHub dispatch token은 이 repo의 rollback workflow를 workflow_dispatch 할 수 있어야 한다.
manual_fix/change는 target_image_tag가 비어 있을 수 있으므로 executor가 currentImageTag로 fallback한다.
manual_fix/open_fix_issue workflow는 현재 요청 기록, artifact, GitHub issue 생성을 수행한다.
restart_deployment/scale_replicas/increase_memory/increase_hpa workflow는 `change-apply.yml`에서 GitOps values patch를 수행한다.
change/open_change_pr workflow는 요청 기록, artifact, GitHub issue 생성까지 수행한다.
DR은 현재 gympt-ops에 실제 전환 switch/workflow가 없으므로 운영 action에서 제외한다.
workflow 파일이 실제 GitHub repository에 존재하는지는 apply 후 GitHub API dispatch smoke test로 최종 확인한다.
```

## 3. Slack signing secret 확인

Slack 승인 버튼은 API Gateway를 통해 `lambda/slack-approval-handler/app.py`로 들어온다.

검증 방식:

```text
X-Slack-Request-Timestamp
X-Slack-Signature
body
Slack signing secret
```

운영 권장 입력 위치:

```text
AWS Secrets Manager: cd-quality-gate/slack/signing-secret
Terraform variable: slack_signing_secret_arn
Lambda env: SLACK_SIGNING_SECRET_ARN
```

fallback:

```text
Terraform variable: slack_signing_secret
Lambda env: SLACK_SIGNING_SECRET
```

권장 흐름:

```text
Slack App Signing Secret
-> AWS Secrets Manager secret 생성
-> terraform.tfvars에 slack_signing_secret_arn만 입력
-> slack-approval-handler Lambda가 Secrets Manager에서 읽음
```

`SLACK_SIGNING_SECRET` 직접 주입은 로컬 테스트나 임시 검증에만 사용한다.

SecretString 형식:

```text
raw string:
  <slack signing secret>

json:
  {"signing_secret":"<slack signing secret>"}
  {"slack_signing_secret":"<slack signing secret>"}
  {"SLACK_SIGNING_SECRET":"<slack signing secret>"}
  {"cd-quality-gate/slack/signing-secret":"<slack signing secret>"}
```

Slack webhook URL secret도 raw URL 또는 JSON key를 지원한다.

```text
raw string:
  https://hooks.slack.com/services/...

json:
  {"url":"https://hooks.slack.com/services/..."}
  {"webhook_url":"https://hooks.slack.com/services/..."}
  {"slack_webhook_url":"https://hooks.slack.com/services/..."}
  {"SLACK_WEBHOOK_URL":"https://hooks.slack.com/services/..."}
  {"cd-quality-gate-prod/slack/webhook-url":"https://hooks.slack.com/services/..."}
```

## 4. Slack 운영 최종 사전 검증

apply 전에 로컬에서 통과해야 하는 항목:

```text
1. scripts/test-local.sh 통과
2. Lambda zip package 생성 통과
3. workflow YAML parse 통과
4. action type -> workflow dispatch contract 통과
5. terraform fmt -check 통과
6. terraform validate 통과
7. terraform plan -out=tfplan 통과
```

apply 후 운영에서 확인해야 하는 항목:

```text
1. Terraform output slack_interactivity_url 확인
2. Slack App Interactivity Request URL에 slack_interactivity_url 등록
3. Slack #cd-deploy-alarm에 배포 완료 알림 수신 확인
4. 실패 배포 또는 fixture 기반으로 1차 실패 알림 수신 확인
5. EventBridge -> analysis-orchestrator -> Bedrock -> Slack 2차 알림 수신 확인
6. Slack 승인 버튼 클릭
7. API Gateway -> slack-approval-handler -> EventBridge DeploymentActionApproved 발행 확인
8. deployment-action-executor가 action별 GitHub workflow_dispatch 실행 확인
9. rollback/fix/change 결과가 GitOps commit, issue, artifact 중 기대 경로로 남는지 확인
```
