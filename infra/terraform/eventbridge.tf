resource "aws_cloudwatch_event_bus" "cd_quality_gate" {
  name = "${local.name_prefix}-bus"
  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "deployment_failed" {
  name           = "${local.name_prefix}-deployment-failed"
  event_bus_name = aws_cloudwatch_event_bus.cd_quality_gate.name

  event_pattern = jsonencode({
    source        = ["cd.quality-gate"]
    "detail-type" = ["DeploymentFailed"]
  })
}

