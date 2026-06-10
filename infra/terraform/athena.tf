resource "aws_athena_database" "logs" {
  name   = replace("${local.name_prefix}_logs", "-", "_")
  bucket = aws_s3_bucket.analysis_results.bucket
}

resource "aws_athena_workgroup" "cd_quality_gate" {
  name = "${local.name_prefix}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.analysis_results.bucket}/athena-results/"
    }
  }

  tags = local.tags
}

