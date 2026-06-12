#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/infra/terraform}"
AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-ksw2}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

PROTECTED_STATE_ADDRESSES=(
  "aws_secretsmanager_secret.slack_webhook_url"
)

usage() {
  cat <<'USAGE'
Usage:
  scripts/aws/destroy-terraform-stack.sh [--execute]

Default mode is dry-run. Use --execute to delete Terraform-managed resources.

Environment:
  TF_DIR            Terraform directory. Default: infra/terraform
  AWS_PROFILE_NAME  AWS CLI profile used for local credentials. Default: ksw2
  AWS_REGION        AWS region. Default: ap-northeast-2
  ENVIRONMENT       Safety environment. Default: prod

Safety:
  - Dry-run runs terraform plan -destroy only.
  - ENVIRONMENT=prod execute is blocked unless ALLOW_PROD=true is set.
  - Existing external secrets listed in PROTECTED_STATE_ADDRESSES are removed
    from Terraform state before destroy, so destroy cannot delete them.
  - If result_bucket_name exists in Terraform output, only that bucket is
    emptied before destroy to avoid BucketNotEmpty failures.
USAGE
}

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
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
  echo "Refusing to destroy prod resources. Set ALLOW_PROD=true only if this is intentional." >&2
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

if [[ "$MODE" == "dry-run" ]]; then
  log "Running terraform destroy plan"
  terraform -chdir="$TF_DIR" plan -destroy
  log "Dry-run complete. Re-run with --execute to destroy this Terraform stack."
  exit 0
fi

for address in "${PROTECTED_STATE_ADDRESSES[@]}"; do
  if terraform -chdir="$TF_DIR" state list | grep -qx "$address"; then
    log "Removing protected external resource from state: $address"
    terraform -chdir="$TF_DIR" state rm "$address"
  fi
done

result_bucket_name="$(terraform -chdir="$TF_DIR" output -raw result_bucket_name 2>/dev/null || true)"
if [[ -n "$result_bucket_name" ]]; then
  log "Emptying Terraform result bucket before destroy: $result_bucket_name"
  aws s3 rm "s3://$result_bucket_name" --recursive --region "$AWS_REGION" || true
fi

log "Destroying Terraform-managed resources"
terraform -chdir="$TF_DIR" destroy -auto-approve
log "Terraform stack destroy complete"
