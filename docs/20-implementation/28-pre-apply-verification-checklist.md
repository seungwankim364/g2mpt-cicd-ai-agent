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

생성 후 확인할 output:

```text
event_bus_name
lambda_function_name
result_bucket_name
athena_database_name
athena_workgroup_name
slack_interactivity_url
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
| `dr` | `dr_workflow_repo` | `dr-failover.yml` | yes |
| `manual_fix` | `manual_fix_workflow_repo` | `manual-fix.yml` | yes |
| `change` | `change_workflow_repo` | `change-apply.yml` | yes |

현재 기본 repository:

```text
rollback/dr/manual_fix/change -> seungwankim364/g2mpt-cicd-ai-agent
app redeploy -> hj-3/gympt-app
```

dispatch input 이름은 아래 파일 사이에서 일치한다.

```text
lambda/deployment-action-executor/app.py
.github/workflows/rollback.yml
.github/workflows/dr-failover.yml
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
`../gympt-ops/gympt-gitops/.github/workflows/rollback.yml`을 추가했다.
기존 PAT가 `gympt-gitops`에 있으므로, 실제 values commit은 해당 workflow가 수행한다.
이 repo의 `GH_WORKFLOW_DISPATCH_TOKEN` 또는 AWS Secrets Manager의 GitHub dispatch token은 `hj-3/gympt-gitops` workflow_dispatch 호출 권한이 필요하다.
실제 values commit은 `gympt-gitops` repo 안의 기존 `GITOPS_PAT`가 수행한다.
dr/manual_fix/change는 target_image_tag가 비어 있을 수 있으므로 executor가 currentImageTag로 fallback한다.
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
