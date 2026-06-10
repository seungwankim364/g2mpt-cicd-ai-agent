#!/usr/bin/env bash
set -euo pipefail

MODE="dry-run"
REGION="${AWS_REGION:-ap-northeast-2}"
TAG_KEY="${TAG_KEY:-Project}"
TAG_VALUE="${TAG_VALUE:-cd-quality-gate}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
STATE_DIR="${STATE_DIR:-.aws-stop-state}"

STOP_EC2="true"
STOP_RDS="true"
SCALE_ECS="true"
SCALE_EKS="true"
SCALE_ASG="true"

usage() {
  cat <<'USAGE'
Usage:
  scripts/aws/stop-after-work.sh [--execute]

Default mode is dry-run. Use --execute to stop or scale down resources.

Environment:
  AWS_REGION   AWS region. Default: ap-northeast-2
  TAG_KEY      Resource tag key. Default: Project
  TAG_VALUE    Resource tag value. Default: cd-quality-gate
  ENVIRONMENT  Safety tag value for Environment. Default: dev
  STATE_DIR    Directory for saving scale state. Default: .aws-stop-state

Safety:
  - Only tagged resources are targeted.
  - Resources must match TAG_KEY=TAG_VALUE and Environment=ENVIRONMENT.
  - ENVIRONMENT=prod is blocked unless ALLOW_PROD=true is set.
  - The script does not delete resources.

Supported actions:
  - Stop EC2 instances
  - Stop RDS DB instances and clusters
  - Scale ECS services desired count to 0
  - Scale EKS managed nodegroups min/desired size to 0
  - Scale Auto Scaling Groups min/desired capacity to 0
USAGE
}

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

run() {
  if [[ "$MODE" == "execute" ]]; then
    "$@"
  else
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
  fi
}

require_aws() {
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI is required" >&2
    exit 127
  fi
}

save_state() {
  local kind="$1"
  local name="$2"
  local payload="$3"
  mkdir -p "$STATE_DIR/$kind"
  printf '%s\n' "$payload" > "$STATE_DIR/$kind/$name.json"
}

list_ec2_instances() {
  aws ec2 describe-instances \
    --region "$REGION" \
    --filters \
      "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
      "Name=tag:Environment,Values=${ENVIRONMENT}" \
      "Name=instance-state-name,Values=running,pending" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text
}

stop_ec2_instances() {
  [[ "$STOP_EC2" == "true" ]] || return 0
  log "Checking EC2 instances"
  local instances
  instances="$(list_ec2_instances)"
  if [[ -z "$instances" ]]; then
    log "No EC2 instances matched"
    return 0
  fi
  log "Stopping EC2 instances: $instances"
  run aws ec2 stop-instances --region "$REGION" --instance-ids $instances
}

list_rds_instances() {
  aws rds describe-db-instances \
    --region "$REGION" \
    --query 'DBInstances[?DBInstanceStatus==`available`].[DBInstanceIdentifier,DBInstanceArn]' \
    --output text
}

rds_has_required_tags() {
  local arn="$1"
  local project_tag
  local env_tag
  project_tag="$(aws rds list-tags-for-resource --region "$REGION" --resource-name "$arn" --query "TagList[?Key=='${TAG_KEY}' && Value=='${TAG_VALUE}'] | length(@)" --output text)"
  env_tag="$(aws rds list-tags-for-resource --region "$REGION" --resource-name "$arn" --query "TagList[?Key=='Environment' && Value=='${ENVIRONMENT}'] | length(@)" --output text)"
  [[ "$project_tag" == "1" && "$env_tag" == "1" ]]
}

stop_rds_instances() {
  [[ "$STOP_RDS" == "true" ]] || return 0
  log "Checking RDS instances"
  local row identifier arn matched="false"
  while read -r identifier arn; do
    [[ -n "${identifier:-}" && -n "${arn:-}" ]] || continue
    if rds_has_required_tags "$arn"; then
      matched="true"
      log "Stopping RDS instance: $identifier"
      run aws rds stop-db-instance --region "$REGION" --db-instance-identifier "$identifier"
    fi
  done < <(list_rds_instances)
  [[ "$matched" == "true" ]] || log "No RDS instances matched"
}

list_rds_clusters() {
  aws rds describe-db-clusters \
    --region "$REGION" \
    --query 'DBClusters[?Status==`available`].[DBClusterIdentifier,DBClusterArn]' \
    --output text
}

stop_rds_clusters() {
  [[ "$STOP_RDS" == "true" ]] || return 0
  log "Checking RDS clusters"
  local row identifier arn matched="false"
  while read -r identifier arn; do
    [[ -n "${identifier:-}" && -n "${arn:-}" ]] || continue
    if rds_has_required_tags "$arn"; then
      matched="true"
      log "Stopping RDS cluster: $identifier"
      run aws rds stop-db-cluster --region "$REGION" --db-cluster-identifier "$identifier"
    fi
  done < <(list_rds_clusters)
  [[ "$matched" == "true" ]] || log "No RDS clusters matched"
}

list_ecs_clusters() {
  aws resourcegroupstaggingapi get-resources \
    --region "$REGION" \
    --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" "Key=Environment,Values=${ENVIRONMENT}" \
    --resource-type-filters ecs:cluster \
    --query 'ResourceTagMappingList[].ResourceARN' \
    --output text
}

scale_ecs_services() {
  [[ "$SCALE_ECS" == "true" ]] || return 0
  log "Checking ECS services"
  local cluster_arn services service_arn service_name desired matched="false"
  for cluster_arn in $(list_ecs_clusters); do
    services="$(aws ecs list-services --region "$REGION" --cluster "$cluster_arn" --query 'serviceArns[]' --output text)"
    for service_arn in $services; do
      desired="$(aws ecs describe-services --region "$REGION" --cluster "$cluster_arn" --services "$service_arn" --query 'services[0].desiredCount' --output text)"
      [[ "$desired" != "0" && "$desired" != "None" ]] || continue
      service_name="${service_arn##*/}"
      matched="true"
      save_state "ecs" "$service_name" "{\"clusterArn\":\"$cluster_arn\",\"serviceArn\":\"$service_arn\",\"desiredCount\":$desired}"
      log "Scaling ECS service to 0: $service_name (was $desired)"
      run aws ecs update-service --region "$REGION" --cluster "$cluster_arn" --service "$service_arn" --desired-count 0
    done
  done
  [[ "$matched" == "true" ]] || log "No ECS services matched"
}

list_eks_clusters() {
  aws resourcegroupstaggingapi get-resources \
    --region "$REGION" \
    --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" "Key=Environment,Values=${ENVIRONMENT}" \
    --resource-type-filters eks:cluster \
    --query 'ResourceTagMappingList[].ResourceARN' \
    --output text |
    tr '\t' '\n' |
    awk -F/ '{print $NF}'
}

scale_eks_nodegroups() {
  [[ "$SCALE_EKS" == "true" ]] || return 0
  log "Checking EKS managed nodegroups"
  local cluster nodegroups nodegroup min_size desired_size max_size matched="false"
  for cluster in $(list_eks_clusters); do
    nodegroups="$(aws eks list-nodegroups --region "$REGION" --cluster-name "$cluster" --query 'nodegroups[]' --output text)"
    for nodegroup in $nodegroups; do
      min_size="$(aws eks describe-nodegroup --region "$REGION" --cluster-name "$cluster" --nodegroup-name "$nodegroup" --query 'nodegroup.scalingConfig.minSize' --output text)"
      desired_size="$(aws eks describe-nodegroup --region "$REGION" --cluster-name "$cluster" --nodegroup-name "$nodegroup" --query 'nodegroup.scalingConfig.desiredSize' --output text)"
      max_size="$(aws eks describe-nodegroup --region "$REGION" --cluster-name "$cluster" --nodegroup-name "$nodegroup" --query 'nodegroup.scalingConfig.maxSize' --output text)"
      [[ "$desired_size" != "0" || "$min_size" != "0" ]] || continue
      matched="true"
      save_state "eks" "${cluster}-${nodegroup}" "{\"cluster\":\"$cluster\",\"nodegroup\":\"$nodegroup\",\"minSize\":$min_size,\"desiredSize\":$desired_size,\"maxSize\":$max_size}"
      log "Scaling EKS nodegroup to 0: $cluster/$nodegroup (min=$min_size desired=$desired_size max=$max_size)"
      run aws eks update-nodegroup-config \
        --region "$REGION" \
        --cluster-name "$cluster" \
        --nodegroup-name "$nodegroup" \
        --scaling-config "minSize=0,desiredSize=0,maxSize=$max_size"
    done
  done
  [[ "$matched" == "true" ]] || log "No EKS nodegroups matched"
}

list_asgs() {
  aws autoscaling describe-auto-scaling-groups \
    --region "$REGION" \
    --query "AutoScalingGroups[?Tags[?Key=='${TAG_KEY}' && Value=='${TAG_VALUE}'] && Tags[?Key=='Environment' && Value=='${ENVIRONMENT}']].[AutoScalingGroupName,MinSize,DesiredCapacity,MaxSize]" \
    --output text
}

scale_asgs() {
  [[ "$SCALE_ASG" == "true" ]] || return 0
  log "Checking Auto Scaling Groups"
  local name min_size desired max_size matched="false"
  while read -r name min_size desired max_size; do
    [[ -n "${name:-}" ]] || continue
    [[ "$desired" != "0" || "$min_size" != "0" ]] || continue
    matched="true"
    save_state "asg" "$name" "{\"autoScalingGroupName\":\"$name\",\"minSize\":$min_size,\"desiredCapacity\":$desired,\"maxSize\":$max_size}"
    log "Scaling ASG to 0: $name (min=$min_size desired=$desired max=$max_size)"
    run aws autoscaling update-auto-scaling-group \
      --region "$REGION" \
      --auto-scaling-group-name "$name" \
      --min-size 0 \
      --desired-capacity 0
  done < <(list_asgs)
  [[ "$matched" == "true" ]] || log "No Auto Scaling Groups matched"
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

if [[ "$ENVIRONMENT" == "prod" && "${ALLOW_PROD:-false}" != "true" ]]; then
  echo "Refusing to stop prod resources. Set ALLOW_PROD=true only if this is intentional." >&2
  exit 3
fi

require_aws

log "Mode: $MODE"
log "Region: $REGION"
log "Tag filter: ${TAG_KEY}=${TAG_VALUE}, Environment=${ENVIRONMENT}"

stop_ec2_instances
stop_rds_instances
stop_rds_clusters
scale_ecs_services
scale_eks_nodegroups
scale_asgs

log "Done"

