resource "aws_s3_bucket" "source_bucket" {
  bucket = "source-bucket"

  versioning {
    enabled = true
  }

  replication_configuration {
    role = aws_iam_role.replication.arn

    rules {
      id     = "replication-rule"
      status = "Enabled"

      destination {
        bucket        = aws_s3_bucket.destination_bucket.arn
        storage_class = "STANDARD"
        replica_kms_key_id = "arn:aws:kms:region:account-id:key/key-id"
      }
    }
  }
}
