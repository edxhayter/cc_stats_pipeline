# --- AWS: IAM role Snowflake's storage integration assumes -----------------
#
# Two-pass apply required (see CLAUDE.md build order): the role's trust policy
# needs the storage integration's own STORAGE_AWS_IAM_USER_ARN / external ID,
# but the storage integration needs this role's ARN to be created. AWS
# validates that a trust policy principal resolves to something real, so an
# invented ARN is rejected outright — the placeholder on the first apply must
# be this account's own root (always a valid principal), which can't itself
# assume anything until the real values are swapped in on the second apply.

data "aws_caller_identity" "current" {}

locals {
  storage_integration_principal_arn = coalesce(
    var.snowflake_storage_aws_iam_user_arn,
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
  )
  storage_integration_external_id = coalesce(
    var.snowflake_storage_aws_external_id,
    "placeholder-until-first-apply",
  )
}

resource "aws_iam_role" "snowflake_storage_integration" {
  name = "${var.storage_integration_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.storage_integration_principal_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.storage_integration_external_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

data "aws_iam_policy_document" "snowflake_s3_access" {
  statement {
    sid       = "AllowListLandingBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.s3_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.s3_prefix}*"]
    }
  }

  statement {
    sid       = "AllowReadLandingObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_bucket_arn}/${var.s3_prefix}*"]
  }

  statement {
    sid       = "AllowKmsDecryptForRead"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.s3_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "snowflake_s3_access" {
  name   = "${var.storage_integration_name}-s3-access"
  role   = aws_iam_role.snowflake_storage_integration.id
  policy = data.aws_iam_policy_document.snowflake_s3_access.json
}

# --- Snowflake: storage integration, database/schema, stage, file format ----

resource "snowflake_storage_integration" "scorecards" {
  name                 = var.storage_integration_name
  type                 = "EXTERNAL_STAGE"
  storage_provider     = "S3"
  enabled              = true
  storage_aws_role_arn = aws_iam_role.snowflake_storage_integration.arn

  storage_allowed_locations = [
    "s3://${var.s3_bucket_name}/${var.s3_prefix}",
  ]
}

# Schema created in var.database_name, an existing database — not managed by
# Terraform (see CLAUDE.md conventions: only new objects this pipeline owns
# are provisioned here).
resource "snowflake_schema" "raw" {
  database = var.database_name
  name     = var.schema_name
}

# FIELD_DELIMITER = 'NONE' — each raw line loads as a single column.
# Do not split fields at COPY INTO time (see CLAUDE.md hard constraints);
# field extraction happens in dbt staging models via SQL/regex.
resource "snowflake_file_format" "scorecard_line" {
  name        = var.file_format_name
  database    = var.database_name
  schema      = snowflake_schema.raw.name
  format_type = "CSV"

  field_delimiter = "NONE"
}

resource "snowflake_stage" "scorecard_landing" {
  name     = var.stage_name
  database = var.database_name
  schema   = snowflake_schema.raw.name

  url                 = "s3://${var.s3_bucket_name}/${var.s3_prefix}"
  storage_integration = snowflake_storage_integration.scorecards.name

  file_format = "FORMAT_NAME = '${var.database_name}.${snowflake_schema.raw.name}.${snowflake_file_format.scorecard_line.name}'"
}

resource "snowflake_table" "scorecard_lines" {
  database = var.database_name
  schema   = snowflake_schema.raw.name
  name     = var.table_name

  column {
    name = "RAW_LINE"
    type = "VARCHAR"
  }

  column {
    name = "SOURCE_FILE_NAME"
    type = "VARCHAR"
  }

  column {
    name = "SOURCE_FILE_ROW_NUMBER"
    type = "NUMBER"
  }

  column {
    name = "LOADED_AT"
    type = "TIMESTAMP_NTZ"
  }
}

# --- Load task ---------------------------------------------------------------
#
# Scheduled COPY INTO on an existing warehouse — not Snowpipe, not an external
# orchestrator, per CLAUDE.md. The dbt task is a separate snowflake_task,
# chained with AFTER, added once the dbt project is deployed (build order
# step 6) — out of scope for this module.

resource "snowflake_task" "load_scorecards" {
  name     = "${var.table_name}_LOAD_TASK"
  database = var.database_name
  schema   = snowflake_schema.raw.name

  warehouse = var.warehouse_name
  started   = true

  schedule {
    using_cron = var.load_task_schedule
  }

  sql_statement = <<-SQL
    COPY INTO ${var.database_name}.${snowflake_schema.raw.name}.${snowflake_table.scorecard_lines.name}
      (RAW_LINE, SOURCE_FILE_NAME, SOURCE_FILE_ROW_NUMBER, LOADED_AT)
    FROM (
      SELECT
        $1,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP()
      FROM @${var.database_name}.${snowflake_schema.raw.name}.${snowflake_stage.scorecard_landing.name}
        (PATTERN => '.*[.]txt')
    )
    FILE_FORMAT = (FORMAT_NAME = '${var.database_name}.${snowflake_schema.raw.name}.${snowflake_file_format.scorecard_line.name}')
    ON_ERROR = 'ABORT_STATEMENT'
  SQL
}
