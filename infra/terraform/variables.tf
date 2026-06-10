variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "cd-quality-gate"
}

variable "result_bucket_name" {
  type    = string
  default = null
}

