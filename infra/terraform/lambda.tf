resource "aws_lambda_function" "analysis_orchestrator" {
  function_name                  = "${local.name_prefix}-analysis-orchestrator"
  role                           = aws_iam_role.analysis_orchestrator.arn
  handler                        = "app.handler"
  runtime                        = "python3.12"
  filename                       = "build/analysis-orchestrator.zip"
  timeout                        = 300
  memory_size                    = 512
  reserved_concurrent_executions = 2

  environment {
    variables = {
      RESULT_BUCKET          = aws_s3_bucket.analysis_results.bucket
      ATHENA_DATABASE        = aws_athena_database.logs.name
      ATHENA_WORKGROUP       = aws_athena_workgroup.cd_quality_gate.name
      ATHENA_OUTPUT_LOCATION = "s3://${aws_s3_bucket.analysis_results.bucket}/athena-results/"
      SLACK_CHANNEL          = "#cd-deploy-alarm"
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

resource "aws_lambda_function" "slack_approval_handler" {
  function_name                  = "${local.name_prefix}-slack-approval-handler"
  role                           = aws_iam_role.slack_approval_handler.arn
  handler                        = "app.handler"
  runtime                        = "python3.12"
  filename                       = "build/slack-approval-handler.zip"
  timeout                        = 10
  memory_size                    = 256
  reserved_concurrent_executions = 2

  environment {
    variables = {
      EVENT_BUS_NAME       = aws_cloudwatch_event_bus.cd_quality_gate.name
      SLACK_SIGNING_SECRET = var.slack_signing_secret
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "deployment_action_executor" {
  function_name                  = "${local.name_prefix}-deployment-action-executor"
  role                           = aws_iam_role.deployment_action_executor.arn
  handler                        = "app.handler"
  runtime                        = "python3.12"
  filename                       = "build/deployment-action-executor.zip"
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 1

  environment {
    variables = {
      GITHUB_TOKEN_SECRET_ARN  = var.github_token_secret_arn
      ROLLBACK_WORKFLOW_REPO   = var.rollback_workflow_repo
      DR_WORKFLOW_REPO         = var.dr_workflow_repo
      MANUAL_FIX_WORKFLOW_REPO = var.manual_fix_workflow_repo
      CHANGE_WORKFLOW_REPO     = var.change_workflow_repo
      WORKFLOW_REF             = "main"
      APP_DEPLOY_WORKFLOW_REPO = var.app_deploy_workflow_repo
      APP_DEPLOY_WORKFLOW_FILE = var.app_deploy_workflow_file
      APP_DEPLOY_WORKFLOW_REF  = var.app_deploy_workflow_ref
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "deployment_action_executor" {
  rule           = aws_cloudwatch_event_rule.deployment_action_approved.name
  event_bus_name = aws_cloudwatch_event_bus.cd_quality_gate.name
  arn            = aws_lambda_function.deployment_action_executor.arn
}

resource "aws_lambda_permission" "allow_eventbridge_approved_action" {
  statement_id  = "AllowExecutionFromEventBridgeApprovedAction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deployment_action_executor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.deployment_action_approved.arn
}
