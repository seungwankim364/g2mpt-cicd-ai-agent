#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-ksw2}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
PROJECT="${PROJECT:-cd-quality-gate}"

DASHBOARD_TARGETS=(
  "aws_lambda_permission.allow_apigateway_dashboard"
  "aws_apigatewayv2_stage.dashboard"
  "aws_apigatewayv2_route.dashboard_api_any"
  "aws_apigatewayv2_integration.dashboard_api"
  "aws_apigatewayv2_api.dashboard"
  "aws_lambda_function.dashboard_api"
  "aws_iam_role_policy.dashboard_api"
  "aws_iam_role.dashboard_api"
  "aws_dynamodb_table.dashboard_actions"
  "aws_s3_object.dashboard"
  "aws_s3_bucket_policy.dashboard"
  "aws_cloudfront_distribution.dashboard"
  "aws_cloudfront_origin_access_control.dashboard"
  "aws_s3_bucket_server_side_encryption_configuration.dashboard"
  "aws_s3_bucket_public_access_block.dashboard"
  "aws_s3_bucket.dashboard"
)

usage() {
  cat <<'USAGE'
Usage:
  scripts/aws/destroy-dashboard-stack.sh [--execute]

Default mode is dry-run. Use --execute to delete only dashboard AWS resources.

Environment:
  TF_DIR            Terraform directory. Default: infra/terraform
  AWS_PROFILE_NAME  AWS CLI profile used for local credentials. Default: ksw2
  AWS_REGION        AWS region. Default: ap-northeast-2
  ENVIRONMENT       Safety environment. Default: prod
  PROJECT           Project name used for fallback bucket name. Default: cd-quality-gate

Safety:
  - Dry-run runs terraform plan -destroy with dashboard targets only.
  - ENVIRONMENT=prod execute is blocked unless ALLOW_PROD=true is set.
  - Only Terraform dashboard targets are destroyed.
  - The dashboard S3 bucket is emptied before destroy to avoid BucketNotEmpty.
  - Core Quality Gate resources, Slack resources, EventBridge, Athena, and result
    bucket are not targeted by this script.
USAGE
}

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

target_args() {
  local target
  for target in "${DASHBOARD_TARGETS[@]}"; do
    printf -- '-target=%s\n' "$target"
  done
}

dashboard_bucket_name() {
  local from_state fallback
  from_state="$(
    terraform -chdir="$TF_DIR" state show 'aws_s3_bucket.dashboard[0]' 2>/dev/null |
      awk -F'=' '/^[[:space:]]*bucket[[:space:]]*=/{gsub(/[ "]/, "", $2); print $2; exit}'
  )"
  fallback="${PROJECT}-${ENVIRONMENT}-dashboard"
  printf '%s\n' "${from_state:-$fallback}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute)
      MODE="execute"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$MODE" == "execute" && "$ENVIRONMENT" == "prod" && "${ALLOW_PROD:-false}" != "true" ]]; then
  echo "Refusing to destroy prod dashboard resources. Set ALLOW_PROD=true only if this is intentional." >&2
  exit 3
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform CLI is required" >&2
  exit 127
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required" >&2
  exit 127
fi

if [[ ! -d "$TF_DIR" ]]; then
  echo "Terraform directory does not exist: $TF_DIR" >&2
  exit 2
fi

if [[ -n "$AWS_PROFILE_NAME" ]]; then
  # shellcheck disable=SC2046
  eval "$(aws configure export-credentials --profile "$AWS_PROFILE_NAME" --format env)"
fi

export AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"

log "Mode: $MODE"
log "Terraform directory: $TF_DIR"
log "Region: $AWS_REGION"
log "Environment: $ENVIRONMENT"

terraform -chdir="$TF_DIR" init -input=false >/dev/null

mapfile -t TARGET_ARGS < <(target_args)

if [[ "$MODE" == "dry-run" ]]; then
  log "Running dashboard-only terraform destroy plan"
  terraform -chdir="$TF_DIR" plan -destroy "${TARGET_ARGS[@]}"
  log "Dry-run complete. Re-run with --execute to destroy dashboard resources."
  exit 0
fi

bucket_name="$(dashboard_bucket_name)"
if aws s3api head-bucket --bucket "$bucket_name" --region "$AWS_REGION" >/dev/null 2>&1; then
  log "Emptying dashboard bucket before destroy: $bucket_name"
  aws s3 rm "s3://$bucket_name" --recursive --region "$AWS_REGION" || true
else
  log "Dashboard bucket not found or not accessible: $bucket_name"
fi

log "Destroying dashboard Terraform targets only"
terraform -chdir="$TF_DIR" destroy -auto-approve "${TARGET_ARGS[@]}"
log "Dashboard resources destroy complete"
