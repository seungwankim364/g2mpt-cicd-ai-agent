data "aws_caller_identity" "current" {}

locals {
  name_prefix              = "${var.project}-${var.environment}"
  result_bucket_name       = coalesce(var.result_bucket_name, "${local.name_prefix}-results")
  slack_webhook_secret_arn = var.slack_webhook_secret_arn != "" ? var.slack_webhook_secret_arn : aws_secretsmanager_secret.slack_webhook_url[0].arn
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostControl = var.auto_stop ? "auto-stop" : "manual"
    Repository  = "cd-quality-gate-architecture"
  }
}
