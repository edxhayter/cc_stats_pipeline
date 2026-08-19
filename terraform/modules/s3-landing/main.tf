data "aws_caller_identity" "current" {}

# --- KMS CMK for landing bucket encryption ---------------------------------

resource "aws_kms_key" "landing" {
  description             = "CMK for the cricket scorecards S3 landing bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "landing" {
  name          = "alias/${var.kms_key_alias}"
  target_key_id = aws_kms_key.landing.key_id
}

# --- Landing bucket ----------------------------------------------------------

resource "aws_s3_bucket" "landing" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.landing.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "landing" {
  bucket                  = aws_s3_bucket.landing.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "landing_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.landing.arn,
      "${aws_s3_bucket.landing.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.landing.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

resource "aws_s3_bucket_policy" "landing" {
  bucket = aws_s3_bucket.landing.id
  policy = data.aws_iam_policy_document.landing_bucket_policy.json
}

# --- Uploader IAM user (used by scripts/local-sync) --------------------------

resource "aws_iam_user" "uploader" {
  name = var.uploader_user_name
  tags = var.tags
}

# Access key is created out-of-band (aws iam create-access-key) and rotated
# manually — not managed here, so the secret never lands in Terraform state.

data "aws_iam_policy_document" "uploader_policy" {
  statement {
    sid    = "AllowPutToLandingBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.landing.arn,
      "${aws_s3_bucket.landing.arn}/*",
    ]
  }

  statement {
    sid    = "AllowKmsEncryptForUploads"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Encrypt",
    ]
    resources = [aws_kms_key.landing.arn]
  }
}

resource "aws_iam_user_policy" "uploader" {
  name   = "${var.uploader_user_name}-s3-upload"
  user   = aws_iam_user.uploader.name
  policy = data.aws_iam_policy_document.uploader_policy.json
}
