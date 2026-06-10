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
