resource "aws_lambda_function" "analysis_orchestrator" {
  function_name                  = "${local.name_prefix}-analysis-orchestrator"
  role                           = aws_iam_role.analysis_orchestrator.arn
  handler                        = "app.handler"
  runtime                        = "python3.12"
  filename                       = "${path.module}/../../build/analysis-orchestrator.zip"
  source_code_hash               = filebase64sha256("${path.module}/../../build/analysis-orchestrator.zip")
  timeout                        = 300
  memory_size                    = 512
  reserved_concurrent_executions = 2

  environment {
    variables = {
      RESULT_BUCKET            = aws_s3_bucket.analysis_results.bucket
      ATHENA_DATABASE          = aws_athena_database.logs.name
      ATHENA_WORKGROUP         = aws_athena_workgroup.cd_quality_gate.name
      ATHENA_OUTPUT_LOCATION   = "s3://${aws_s3_bucket.analysis_results.bucket}/athena-results/"
      BEDROCK_ENABLED          = tostring(var.bedrock_enabled)
      BEDROCK_MODEL_ID         = var.bedrock_model_id
      BEDROCK_REGION           = var.aws_region
      BEDROCK_MAX_TOKENS       = tostring(var.bedrock_max_tokens)
      SLACK_CHANNEL            = "#cd-deploy-alarm"
      SLACK_WEBHOOK_SECRET_ARN = local.slack_webhook_secret_arn
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
  filename                       = "${path.module}/../../build/slack-approval-handler.zip"
  source_code_hash               = filebase64sha256("${path.module}/../../build/slack-approval-handler.zip")
  timeout                        = 10
  memory_size                    = 256
  reserved_concurrent_executions = 2

  environment {
    variables = {
      EVENT_BUS_NAME           = aws_cloudwatch_event_bus.cd_quality_gate.name
      SLACK_SIGNING_SECRET     = var.slack_signing_secret
      SLACK_SIGNING_SECRET_ARN = var.slack_signing_secret_arn
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "deployment_action_executor" {
  function_name                  = "${local.name_prefix}-deployment-action-executor"
  role                           = aws_iam_role.deployment_action_executor.arn
  handler                        = "app.handler"
  runtime                        = "python3.12"
  filename                       = "${path.module}/../../build/deployment-action-executor.zip"
  source_code_hash               = filebase64sha256("${path.module}/../../build/deployment-action-executor.zip")
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 1

  environment {
    variables = {
      GITHUB_TOKEN_SECRET_ARN  = var.github_token_secret_arn
      ROLLBACK_WORKFLOW_REPO   = var.rollback_workflow_repo
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

resource "aws_lambda_function" "github_webhook_handler" {
  function_name                  = "${local.name_prefix}-github-webhook-handler"
  role                           = aws_iam_role.github_webhook_handler.arn
  handler                        = "app.handler"
  runtime                        = "python3.12"
  filename                       = "${path.module}/../../build/github-webhook-handler.zip"
  source_code_hash               = filebase64sha256("${path.module}/../../build/github-webhook-handler.zip")
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 2

  environment {
    variables = {
      GITHUB_TOKEN_SECRET_ARN    = var.github_token_secret_arn
      GITHUB_WEBHOOK_SECRET_ARN  = var.github_webhook_secret_arn
      EXPECTED_REPOSITORY        = var.app_deploy_workflow_repo
      EXPECTED_WORKFLOW_NAME     = var.app_deploy_workflow_name
      EXPECTED_BRANCH            = var.app_deploy_workflow_ref
      QUALITY_GATE_REPO          = var.quality_gate_workflow_repo
      QUALITY_GATE_WORKFLOW_FILE = var.quality_gate_workflow_file
      QUALITY_GATE_REF           = var.quality_gate_workflow_ref
      SERVICE_NAME               = "backend-api"
      ENVIRONMENT                = var.environment
      K8S_NAMESPACE              = "gympt-prod"
      K8S_DEPLOYMENT             = "backend-api-prod"
      IMAGE_REPOSITORY           = "337112169365.dkr.ecr.${var.aws_region}.amazonaws.com/gympt-prod/backend-api"
      PROMETHEUS_URL             = var.quality_gate_prometheus_url
      GRAFANA_URL                = var.quality_gate_grafana_url
      ARGOCD_URL                 = var.quality_gate_argocd_url
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
