locals {
  dashboard_bucket_name = coalesce(var.dashboard_bucket_name, "${local.name_prefix}-dashboard")
  dashboard_static_files = var.enable_dashboard ? toset([
    for file in fileset("${path.module}/../../dashboard", "**") : file
    if !startswith(file, "runtime/") && file != "README.md" && file != "server.mjs"
  ]) : toset([])
  dashboard_content_types = {
    html = "text/html; charset=utf-8"
    js   = "text/javascript; charset=utf-8"
    css  = "text/css; charset=utf-8"
    json = "application/json; charset=utf-8"
  }
}

resource "aws_s3_bucket" "dashboard" {
  count  = var.enable_dashboard ? 1 : 0
  bucket = local.dashboard_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "dashboard" {
  count                   = var.enable_dashboard ? 1 : 0
  bucket                  = aws_s3_bucket.dashboard[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dashboard" {
  count  = var.enable_dashboard ? 1 : 0
  bucket = aws_s3_bucket.dashboard[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "dashboard" {
  count                             = var.enable_dashboard ? 1 : 0
  name                              = "${local.name_prefix}-dashboard-oac"
  description                       = "OAC for the CD Quality Gate dashboard"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "dashboard" {
  count               = var.enable_dashboard ? 1 : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  comment             = "${local.name_prefix} dashboard"
  tags                = local.tags

  origin {
    domain_name              = aws_s3_bucket.dashboard[0].bucket_regional_domain_name
    origin_id                = "dashboard-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.dashboard[0].id
  }

  origin {
    domain_name = replace(aws_apigatewayv2_api.dashboard[0].api_endpoint, "https://", "")
    origin_id   = "dashboard-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "dashboard-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "api/*"
    target_origin_id       = "dashboard-api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true
    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method", "Content-Type"]

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "dashboard" {
  count  = var.enable_dashboard ? 1 : 0
  bucket = aws_s3_bucket.dashboard[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.dashboard[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.dashboard[0].arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "dashboard" {
  for_each = local.dashboard_static_files

  bucket       = aws_s3_bucket.dashboard[0].id
  key          = each.value
  source       = "${path.module}/../../dashboard/${each.value}"
  etag         = filemd5("${path.module}/../../dashboard/${each.value}")
  content_type = lookup(local.dashboard_content_types, lower(regex("[^.]+$", each.value)), "application/octet-stream")
}

resource "aws_dynamodb_table" "dashboard_actions" {
  count        = var.enable_dashboard ? 1 : 0
  name         = "${local.name_prefix}-dashboard-actions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.tags
}

resource "aws_iam_role" "dashboard_api" {
  count = var.enable_dashboard ? 1 : 0
  name  = "${local.name_prefix}-dashboard-api"
  tags  = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "dashboard_api" {
  count = var.enable_dashboard ? 1 : 0
  name  = "${local.name_prefix}-dashboard-api"
  role  = aws_iam_role.dashboard_api[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.dashboard_actions[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = aws_cloudwatch_event_bus.cd_quality_gate.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.analysis_results.arn,
          "${aws_s3_bucket.analysis_results.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = length(compact([
          var.github_token_secret_arn,
          var.dashboard_argocd_token_secret_arn
          ])) > 0 ? compact([
          var.github_token_secret_arn,
          var.dashboard_argocd_token_secret_arn
        ]) : ["*"]
      }
    ]
  })
}

resource "aws_lambda_function" "dashboard_api" {
  count                          = var.enable_dashboard ? 1 : 0
  function_name                  = "${local.name_prefix}-dashboard-api"
  role                           = aws_iam_role.dashboard_api[0].arn
  handler                        = "app.handler"
  runtime                        = "python3.12"
  filename                       = "${path.module}/../../build/dashboard-api.zip"
  timeout                        = 15
  memory_size                    = 256
  reserved_concurrent_executions = 2

  environment {
    variables = {
      EVENT_BUS_NAME          = aws_cloudwatch_event_bus.cd_quality_gate.name
      ACTION_TABLE_NAME       = aws_dynamodb_table.dashboard_actions[0].name
      RESULT_BUCKET           = aws_s3_bucket.analysis_results.bucket
      GITHUB_TOKEN_SECRET_ARN = var.github_token_secret_arn
      GITHUB_REPOSITORY       = var.app_deploy_workflow_repo
      GITHUB_WORKFLOW_FILE    = var.app_deploy_workflow_file
      GITHUB_BRANCH           = var.app_deploy_workflow_ref
      ARGOCD_URL              = var.dashboard_argocd_url
      ARGOCD_APP              = "backend-api-prod"
      ARGOCD_TOKEN_SECRET_ARN = var.dashboard_argocd_token_secret_arn
      PROMETHEUS_URL          = var.dashboard_prometheus_url
    }
  }

  tags = local.tags
}

resource "aws_apigatewayv2_api" "dashboard" {
  count         = var.enable_dashboard ? 1 : 0
  name          = "${local.name_prefix}-dashboard"
  protocol_type = "HTTP"
  tags          = local.tags

  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["*"]
  }
}

resource "aws_apigatewayv2_integration" "dashboard_api" {
  count                  = var.enable_dashboard ? 1 : 0
  api_id                 = aws_apigatewayv2_api.dashboard[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.dashboard_api[0].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "dashboard_api_any" {
  count     = var.enable_dashboard ? 1 : 0
  api_id    = aws_apigatewayv2_api.dashboard[0].id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.dashboard_api[0].id}"
}

resource "aws_apigatewayv2_stage" "dashboard" {
  count       = var.enable_dashboard ? 1 : 0
  api_id      = aws_apigatewayv2_api.dashboard[0].id
  name        = "$default"
  auto_deploy = true
  tags        = local.tags
}

resource "aws_lambda_permission" "allow_apigateway_dashboard" {
  count         = var.enable_dashboard ? 1 : 0
  statement_id  = "AllowExecutionFromApiGatewayDashboard"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dashboard_api[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.dashboard[0].execution_arn}/*/*"
}
