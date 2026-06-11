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

variable "github_token_secret_arn" {
  type    = string
  default = ""
}

variable "rollback_workflow_repo" {
  type    = string
  default = "seungwankim364/g2mpt-cicd-ai-agent"
}

variable "dr_workflow_repo" {
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
