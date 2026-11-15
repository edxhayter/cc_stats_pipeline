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

  # Resources the 2.x provider still treats as preview: the Cortex Agent
  # (cortex_agent.tf), and the generic file format/stage/storage
  # integration/table resources used by the ingest module and agent_evals.tf,
  # and the parameters data source behind the web search check.
  preview_features_enabled = [
    "snowflake_cortex_agent_resource",
    "snowflake_file_format_resource",
    "snowflake_parameters_datasource",
    "snowflake_stage_resource",
    "snowflake_storage_integration_resource",
    "snowflake_table_resource",
  ]
}
