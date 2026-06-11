output "event_bus_name" {
  value = aws_cloudwatch_event_bus.cd_quality_gate.name
}

output "slack_channel" {
  value = "#cd-deploy-alarm"
}

output "required_resource_tags" {
  value = local.tags
}

output "event_bus_arn" {
  value = aws_cloudwatch_event_bus.cd_quality_gate.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.analysis_orchestrator.function_name
}

output "result_bucket_name" {
  value = aws_s3_bucket.analysis_results.bucket
}

output "athena_database_name" {
  value = aws_athena_database.logs.name
}

output "athena_workgroup_name" {
  value = aws_athena_workgroup.cd_quality_gate.name
}

output "slack_interactivity_url" {
  value = "${aws_apigatewayv2_api.slack_approval.api_endpoint}/slack/interactions"
}
