variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "project" {
  type    = string
  default = "cd-quality-gate"
}

variable "owner" {
  type    = string
  default = "personal-cd-quality-gate"
}

variable "auto_stop" {
  type        = bool
  default     = true
  description = "Marks resources as safe for after-work stop/scale-down scripts."
}

variable "result_bucket_name" {
  type    = string
  default = null
}

variable "slack_signing_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "slack_signing_secret_arn" {
  type        = string
  default     = ""
  description = "AWS Secrets Manager ARN for Slack app signing secret. Prefer this over slack_signing_secret."
}

variable "slack_webhook_secret_arn" {
  type        = string
  default     = ""
  description = "AWS Secrets Manager ARN for Slack incoming webhook URL. When set, Terraform reuses the existing secret instead of creating one."
}

variable "github_token_secret_arn" {
  type    = string
  default = ""
}

variable "dashboard_argocd_token_secret_arn" {
  type        = string
  default     = ""
  description = "Optional AWS Secrets Manager ARN for an Argo CD API token used by the dashboard live status integration."
}

variable "dashboard_argocd_url" {
  type        = string
  default     = "https://argocd.g2mpt.com"
  description = "Argo CD base URL used by the dashboard live status integration."
}

variable "dashboard_prometheus_url" {
  type        = string
  default     = "http://kube-prometheus-stack-prometheus.monitoring.svc:9090"
  description = "Prometheus base URL used by the dashboard live alert integration."
}

variable "github_webhook_secret_arn" {
  type        = string
  default     = ""
  description = "AWS Secrets Manager ARN for the GitHub webhook secret used by hj-3/gympt-app repository webhooks."
}

variable "bedrock_enabled" {
  type        = bool
  default     = true
  description = "Use Amazon Bedrock for AI incident analysis. Local rule-based ai-agent remains the fallback."
}

variable "bedrock_model_id" {
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
  description = "Amazon Bedrock model id used by the analysis orchestrator."
}

variable "bedrock_max_tokens" {
  type    = number
  default = 1200
}

variable "rollback_workflow_repo" {
  type    = string
  default = "seungwankim364/g2mpt-cicd-ai-agent"
}

variable "manual_fix_workflow_repo" {
  type    = string
  default = "seungwankim364/g2mpt-cicd-ai-agent"
}

variable "change_workflow_repo" {
  type    = string
  default = "seungwankim364/g2mpt-cicd-ai-agent"
}

variable "app_deploy_workflow_repo" {
  type    = string
  default = "hj-3/gympt-app"
}

variable "app_deploy_workflow_file" {
  type    = string
  default = "backend-api-ci.yml"
}

variable "app_deploy_workflow_ref" {
  type    = string
  default = "main"
}

variable "app_deploy_workflow_name" {
  type    = string
  default = "Backend API CI/CD"
}

variable "quality_gate_workflow_repo" {
  type    = string
  default = "seungwankim364/g2mpt-cicd-ai-agent"
}

variable "quality_gate_workflow_file" {
  type    = string
  default = "quality-gate.yml"
}

variable "quality_gate_workflow_ref" {
  type    = string
  default = "main"
}

variable "enable_dashboard" {
  type        = bool
  default     = false
  description = "Create the optional AWS-hosted dashboard stack. Keep false until Slack-only operations are validated."
}

variable "dashboard_bucket_name" {
  type        = string
  default     = null
  description = "Optional S3 bucket name for the dashboard static frontend."
}
