resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  acl    = var.bucket_acl

  tags = var.tags
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm
    }
  }
}

# This is an example of how you might manage public access blocks
resource "aws_s3_bucket_public_access_block" "access_block" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls   = var.block_public_acls
  block_public_policy = var.block_public_policy
  ignore_public_acls  = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions   = var.policy_actions
    resources = [aws_s3_bucket.bucket.arn]
    principals {
      type        = "AWS"
      identifiers = var.policy_principals
    }
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = var.policy_prefixes
    }
  }
}
