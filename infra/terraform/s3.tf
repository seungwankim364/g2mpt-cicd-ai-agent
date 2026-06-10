resource "aws_s3_bucket" "analysis_results" {
  bucket = local.result_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "analysis_results" {
  bucket                  = aws_s3_bucket.analysis_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analysis_results" {
  bucket = aws_s3_bucket.analysis_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

