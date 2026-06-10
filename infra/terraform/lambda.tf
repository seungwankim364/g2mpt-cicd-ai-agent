resource "aws_lambda_function" "analysis_orchestrator" {
  function_name = "${local.name_prefix}-analysis-orchestrator"
  role          = aws_iam_role.analysis_orchestrator.arn
  handler       = "app.handler"
  runtime       = "python3.12"
  filename      = "build/analysis-orchestrator.zip"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      RESULT_BUCKET          = aws_s3_bucket.analysis_results.bucket
      ATHENA_DATABASE        = aws_athena_database.logs.name
      ATHENA_WORKGROUP       = aws_athena_workgroup.cd_quality_gate.name
      ATHENA_OUTPUT_LOCATION = "s3://${aws_s3_bucket.analysis_results.bucket}/athena-results/"
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "analysis_orchestrator" {
  rule           = aws_cloudwatch_event_rule.deployment_failed.name
  event_bus_name = aws_cloudwatch_event_bus.cd_quality_gate.name
  arn            = aws_lambda_function.analysis_orchestrator.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analysis_orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.deployment_failed.arn
}

