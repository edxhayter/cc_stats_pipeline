variable "s3_bucket_name" {
  description = "Name of the S3 landing bucket (from the s3-landing module)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 landing bucket (from the s3-landing module)"
  type        = string
}

variable "s3_kms_key_arn" {
  description = "ARN of the KMS CMK protecting the landing bucket (from the s3-landing module)"
  type        = string
}

variable "s3_prefix" {
  description = "Key prefix within the landing bucket that scorecard files land under"
  type        = string
  default     = ""
}

variable "database_name" {
  description = "Existing Snowflake database this pipeline's schema is created in. Not provisioned by Terraform — must already exist."
  type        = string
}

variable "schema_name" {
  description = "Snowflake schema to create for raw ingested data"
  type        = string
  default     = "CRICKET_SCORECARDS_RAW"
}

variable "table_name" {
  description = "Name of the raw scorecard lines table"
  type        = string
  default     = "SCORECARD_LINES"
}

variable "warehouse_name" {
  description = "Name of the existing Snowflake warehouse the load task runs on. Not provisioned by Terraform — must already exist. Must be uppercase (Snowflake unquoted identifier requirement)."
  type        = string

  validation {
    condition     = var.warehouse_name == upper(var.warehouse_name)
    error_message = "warehouse_name must be uppercase to match Snowflake's unquoted identifier requirement for the snowflake_task warehouse argument."
  }
}

variable "storage_integration_name" {
  description = "Name of the Snowflake storage integration"
  type        = string
  default     = "CRICKET_SCORECARDS_S3_INTEGRATION"
}

variable "stage_name" {
  description = "Name of the Snowflake external stage"
  type        = string
  default     = "SCORECARD_LANDING_STAGE"
}

variable "file_format_name" {
  description = "Name of the Snowflake file format used to load raw scorecard lines"
  type        = string
  default     = "SCORECARD_LINE_FORMAT"
}

variable "load_task_schedule" {
  description = "Cron expression (with timezone) for the load task's schedule block, e.g. \"0 3 * * * UTC\" for daily at 03:00 UTC"
  type        = string
  default     = "0 3 * * * UTC"
}

variable "snowflake_storage_aws_iam_user_arn" {
  description = <<-EOT
    ARN of the IAM user Snowflake uses to assume the storage integration role.
    Unknown until the storage integration is first created — leave unset (null)
    on the first apply, which falls back to trusting this account's own root
    (a valid placeholder principal). Set this from `terraform output` and
    re-apply for the real trust policy (two-pass apply, see CLAUDE.md build
    order).
  EOT
  type        = string
  default     = null
}

variable "snowflake_storage_aws_external_id" {
  description = <<-EOT
    External ID Snowflake's storage integration expects when assuming the role.
    Unknown until the storage integration is first created — leave unset (null)
    on the first apply, then set this from `terraform output` and re-apply.
  EOT
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to AWS resources in this module"
  type        = map(string)
  default     = {}
}
