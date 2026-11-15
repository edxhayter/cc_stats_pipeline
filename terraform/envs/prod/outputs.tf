output "landing_bucket_name" {
  value = module.s3_landing.bucket_name
}

output "landing_bucket_arn" {
  value = module.s3_landing.bucket_arn
}

output "landing_kms_key_arn" {
  value = module.s3_landing.kms_key_arn
}

output "uploader_user_name" {
  value = module.s3_landing.uploader_user_name
}

output "snowflake_storage_aws_iam_user_arn" {
  description = "Feed into snowflake_storage_aws_iam_user_arn for the second apply pass"
  value       = module.snowflake_ingest.storage_aws_iam_user_arn
}

output "snowflake_storage_aws_external_id" {
  description = "Feed into snowflake_storage_aws_external_id for the second apply pass"
  value       = module.snowflake_ingest.storage_aws_external_id
}

output "snowflake_raw_table_fqn" {
  value = module.snowflake_ingest.raw_table_fqn
}

output "snowflake_load_task_name" {
  value = module.snowflake_ingest.load_task_name
}

output "gha_terraform_plan_role_arn" {
  description = "Set as GitHub variable AWS_PLAN_ROLE_ARN"
  value       = aws_iam_role.gha_terraform_plan.arn
}

output "gha_terraform_apply_role_arn" {
  description = "Set as GitHub variable AWS_APPLY_ROLE_ARN (production environment)"
  value       = aws_iam_role.gha_terraform_apply.arn
}

output "dbt_deps_external_access_integration" {
  value = snowflake_external_access_integration.dbt_deps.name
}
