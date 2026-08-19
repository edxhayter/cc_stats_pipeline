output "storage_integration_name" {
  value = snowflake_storage_integration.scorecards.name
}

output "storage_aws_iam_user_arn" {
  description = "Real IAM user ARN from the created storage integration — feed into snowflake_storage_aws_iam_user_arn for the second apply pass"
  value       = snowflake_storage_integration.scorecards.storage_aws_iam_user_arn
}

output "storage_aws_external_id" {
  description = "Real external ID from the created storage integration — feed into snowflake_storage_aws_external_id for the second apply pass"
  value       = snowflake_storage_integration.scorecards.storage_aws_external_id
}

output "iam_role_arn" {
  value = aws_iam_role.snowflake_storage_integration.arn
}

output "database_name" {
  value = var.database_name
}

output "schema_name" {
  value = snowflake_schema.raw.name
}

output "raw_table_fqn" {
  value = "${var.database_name}.${snowflake_schema.raw.name}.${snowflake_table.scorecard_lines.name}"
}

output "stage_fqn" {
  value = "${var.database_name}.${snowflake_schema.raw.name}.${snowflake_stage.scorecard_landing.name}"
}

output "load_task_name" {
  value = snowflake_task.load_scorecards.name
}
