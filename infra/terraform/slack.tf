resource "aws_secretsmanager_secret" "slack_webhook_url" {
  name = "${local.name_prefix}/slack/webhook-url"
  tags = local.tags
}

