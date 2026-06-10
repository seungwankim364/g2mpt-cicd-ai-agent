locals {
  name_prefix        = "${var.project}-${var.environment}"
  result_bucket_name = coalesce(var.result_bucket_name, "${local.name_prefix}-results")
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

