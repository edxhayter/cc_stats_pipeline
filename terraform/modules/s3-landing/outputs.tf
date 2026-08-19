output "bucket_name" {
  description = "Name of the S3 landing bucket"
  value       = aws_s3_bucket.landing.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 landing bucket"
  value       = aws_s3_bucket.landing.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt landing bucket objects"
  value       = aws_kms_key.landing.arn
}

output "uploader_user_name" {
  description = "Name of the IAM user used by scripts/local-sync"
  value       = aws_iam_user.uploader.name
}
