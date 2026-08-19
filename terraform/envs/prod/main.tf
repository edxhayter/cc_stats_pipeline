module "s3_landing" {
  source = "../../modules/s3-landing"

  bucket_name = var.landing_bucket_name
  tags        = var.tags
}

module "snowflake_ingest" {
  source = "../../modules/snowflake-ingest"

  s3_bucket_name = module.s3_landing.bucket_name
  s3_bucket_arn  = module.s3_landing.bucket_arn
  s3_kms_key_arn = module.s3_landing.kms_key_arn

  database_name  = var.snowflake_database_name
  warehouse_name = var.snowflake_warehouse_name
  tags           = var.tags

  # Two-pass apply: leave these unset (null) for the first apply — the module
  # falls back to trusting this account's own root as a valid placeholder.
  # After the first apply, set the real values from `terraform output` and
  # re-apply.
  snowflake_storage_aws_iam_user_arn = var.snowflake_storage_aws_iam_user_arn
  snowflake_storage_aws_external_id  = var.snowflake_storage_aws_external_id
}
