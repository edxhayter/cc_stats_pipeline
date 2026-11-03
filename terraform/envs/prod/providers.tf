provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "snowflake" {
  organization_name      = var.snowflake_organization_name
  account_name           = var.snowflake_account_name
  user                   = var.snowflake_user
  authenticator          = "SNOWFLAKE_JWT"
  role                   = var.snowflake_role
  private_key            = file(var.snowflake_private_key_path)
  private_key_passphrase = var.snowflake_private_passphrase
  warehouse              = var.snowflake_warehouse_name

  # Resources the 2.x provider still gates as preview. The provider's
  # preview list includes the stage/file_format/table/storage_integration
  # resources the ingest module was written against under 0.x, so they're
  # enabled here too — without them a 2.x plan refuses those resources.
  preview_features_enabled = [
    "snowflake_cortex_agent_resource",
    "snowflake_external_access_integration_resource",
    "snowflake_file_format_resource",
    "snowflake_network_rule_resource",
    "snowflake_stage_resource",
    "snowflake_storage_integration_resource",
    "snowflake_table_resource",
  ]
}
