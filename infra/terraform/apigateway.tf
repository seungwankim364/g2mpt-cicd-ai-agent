resource "aws_apigatewayv2_api" "slack_approval" {
  name          = "${local.name_prefix}-slack-approval"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "slack_approval_handler" {
  api_id                 = aws_apigatewayv2_api.slack_approval.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.slack_approval_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "slack_interactions" {
  api_id    = aws_apigatewayv2_api.slack_approval.id
  route_key = "POST /slack/interactions"
  target    = "integrations/${aws_apigatewayv2_integration.slack_approval_handler.id}"
}

resource "aws_apigatewayv2_stage" "slack_approval" {
  api_id      = aws_apigatewayv2_api.slack_approval.id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

resource "aws_lambda_permission" "allow_apigateway_slack_approval" {
  statement_id  = "AllowExecutionFromApiGatewaySlackApproval"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_approval_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.slack_approval.execution_arn}/*/*"
}
