resource "aws_secretsmanager_secret" "slack_webhook_url" {
  count = var.slack_webhook_secret_arn == "" ? 1 : 0

  name = "${local.name_prefix}/slack/webhook-url"
  tags = local.tags
}
