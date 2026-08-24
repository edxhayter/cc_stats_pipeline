variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use for authentication"
  type        = string
  default     = null
}

variable "landing_bucket_name" {
  description = "Name of the S3 landing bucket for raw scorecard uploads"
  type        = string
}

variable "snowflake_organization_name" {
  description = "Snowflake organization name (part of the account identifier)"
  type        = string
}

variable "snowflake_account_name" {
  description = "Snowflake account name (part of the account identifier)"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake service user Terraform authenticates as (key-pair auth)"
  type        = string
}

variable "snowflake_role" {
  description = "Snowflake role Terraform operates as"
  type        = string
}

variable "snowflake_private_key_path" {
  description = "Path to the local PEM private key file for Snowflake key-pair auth. Not committed to the repo."
  type        = string
}

variable "snowflake_private_passphrase" {
  description = "Passphrase for the Snowflake private key file, if it's encrypted. Not committed to the repo."
  type        = string
  default     = null
  sensitive   = true
}

variable "snowflake_database_name" {
  description = "Existing Snowflake database this pipeline's schema is created in. Not provisioned by Terraform."
  type        = string
}

variable "snowflake_warehouse_name" {
  description = "Name of the existing Snowflake warehouse the load task runs on. Not provisioned by Terraform."
  type        = string
}

variable "snowflake_semantic_schema" {
  description = <<-EOT
    Schema the dbt project builds marts and the semantic view into (its
    own dbt profile target schema — not the same as the Terraform-managed
    raw ingest schema). Not provisioned by Terraform; dbt owns its
    lifecycle. Referenced here only so the Cortex Agent can point at the
    semantic view by fully qualified name.
  EOT
  type        = string
  default     = "CRICKET_SCORECARDS"
}

variable "snowflake_storage_aws_iam_user_arn" {
  description = "Real value from `terraform output storage_aws_iam_user_arn` on the second apply pass; leave the module default on the first apply."
  type        = string
  default     = null
}

variable "snowflake_storage_aws_external_id" {
  description = "Real value from `terraform output storage_aws_external_id` on the second apply pass; leave the module default on the first apply."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "cricket-scorecards"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
