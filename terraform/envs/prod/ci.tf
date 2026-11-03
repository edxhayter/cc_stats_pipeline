# Identities and integrations the GitHub Actions pipelines need
# (.github/workflows/). Bootstrap: this file must be applied locally once
# before the pipelines can run — CI can't create the identities it
# authenticates as.
#
# Changes to the CI roles themselves also need a local apply: the apply
# role deliberately has no IAM rights over the gha-* roles, so a merged PR
# can't widen CI's own permissions.

data "aws_caller_identity" "current" {}

# --- AWS: GitHub OIDC ---------------------------------------------------------

# One OIDC provider per AWS account per issuer. If the account already has
# one for GitHub (another repo created it), set create_github_oidc_provider
# = false and the existing one is referenced by ARN instead.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

locals {
  github_oidc_provider_arn = (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  )
  state_bucket_arn = "arn:aws:s3:::${var.tf_state_bucket_name}"
}

data "aws_iam_policy_document" "gha_trust" {
  for_each = {
    # PR checks: any pull_request run in this repo.
    plan = "repo:${var.github_repository}:pull_request"
    # Deploy: only jobs bound to the `production` GitHub environment, so
    # environment protection rules (required reviewers) gate every apply.
    apply = "repo:${var.github_repository}:environment:production"
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value]
    }
  }
}

resource "aws_iam_role" "gha_terraform_plan" {
  name               = "gha-cc-stats-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.gha_trust["plan"].json
  tags               = var.tags
}

resource "aws_iam_role" "gha_terraform_apply" {
  name               = "gha-cc-stats-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.gha_trust["apply"].json
  tags               = var.tags
}

# Both roles refresh every resource during plan.
resource "aws_iam_role_policy_attachment" "gha_read_only" {
  for_each = {
    plan  = aws_iam_role.gha_terraform_plan.name
    apply = aws_iam_role.gha_terraform_apply.name
  }

  role       = each.value
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# State read/write, including the S3-native lock file (use_lockfile).
data "aws_iam_policy_document" "tf_state" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/${var.tf_state_key_prefix}*"]
  }
}

resource "aws_iam_role_policy" "gha_tf_state" {
  for_each = {
    plan  = aws_iam_role.gha_terraform_plan.name
    apply = aws_iam_role.gha_terraform_apply.name
  }

  name   = "terraform-state"
  role   = each.value
  policy = data.aws_iam_policy_document.tf_state.json
}

# Write access scoped to what this project's Terraform manages.
data "aws_iam_policy_document" "gha_apply" {
  statement {
    sid     = "LandingBucket"
    actions = ["s3:*"]
    resources = [
      module.s3_landing.bucket_arn,
      "${module.s3_landing.bucket_arn}/*",
    ]
  }
  statement {
    # KMS has no name-scoped ARN at create time; CreateKey needs "*".
    sid       = "Kms"
    actions   = ["kms:*"]
    resources = ["*"]
  }
  statement {
    sid     = "ProjectIamPrincipals"
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${module.s3_landing.uploader_user_name}",
      module.snowflake_ingest.iam_role_arn,
    ]
  }
}

resource "aws_iam_role_policy" "gha_apply" {
  name   = "terraform-apply"
  role   = aws_iam_role.gha_terraform_apply.name
  policy = data.aws_iam_policy_document.gha_apply.json
}

# --- Snowflake: CI service user ----------------------------------------------

# Key-pair auth rather than workload identity: snowflake_service_user can't
# set WORKLOAD_IDENTITY yet, and Terraform's provider already uses JWT. One
# identity covers terraform, the Snowflake CLI, and the eval runner.
resource "snowflake_service_user" "github_actions" {
  name              = var.ci_snowflake_user_name
  comment           = "GitHub Actions CI/CD for ${var.github_repository}"
  rsa_public_key    = var.ci_snowflake_rsa_public_key
  default_role      = var.snowflake_role
  default_warehouse = var.snowflake_warehouse_name
}

# Same role Terraform runs as locally. Narrow this once the planned
# loader / dbt / BI role split lands.
resource "snowflake_grant_account_role" "github_actions" {
  role_name = var.snowflake_role
  user_name = snowflake_service_user.github_actions.name
}

# --- Snowflake: dbt deps from inside Snowflake --------------------------------

# dbt Projects on Snowflake runs `dbt deps` at compile time, which needs
# egress to dbt Hub (package index) and GitHub (package tarballs). Used by
# the dbt deploy step and, later, the scheduled dbt task.
resource "snowflake_network_rule" "dbt_deps" {
  name       = "DBT_DEPS_EGRESS"
  database   = var.snowflake_database_name
  schema     = module.snowflake_ingest.schema_name
  type       = "HOST_PORT"
  mode       = "EGRESS"
  value_list = ["hub.getdbt.com", "codeload.github.com"]
  comment    = "dbt Hub + GitHub package downloads for dbt deps."
}

resource "snowflake_external_access_integration" "dbt_deps" {
  name                  = "CC_STATS_DBT_DEPS"
  allowed_network_rules = [snowflake_network_rule.dbt_deps.fully_qualified_name]
  enabled               = true
  comment               = "Lets the cc_scorecard_transform dbt project object run dbt deps."
}
