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

  # Required for snowflake_cortex_agent (see cortex_agent.tf) — that
  # resource is a preview feature in the provider as of this writing.
  preview_features_enabled = ["snowflake_cortex_agent_resource"]
}
