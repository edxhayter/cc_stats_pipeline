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
}
