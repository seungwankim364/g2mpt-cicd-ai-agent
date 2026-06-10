resource "aws_iam_role" "analysis_orchestrator" {
  name = "${local.name_prefix}-analysis-orchestrator"
  tags = local.tags

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

resource "aws_iam_role_policy" "analysis_orchestrator" {
  name = "${local.name_prefix}-analysis-orchestrator"
  role = aws_iam_role.analysis_orchestrator.id

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
          "s3:GetObject",
          "s3:PutObject",
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
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "glue:GetDatabase",
          "glue:GetTable"
        ]
        Resource = "*"
      }
    ]
  })
}

