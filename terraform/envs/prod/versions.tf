terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    snowflake = {
      source = "snowflakedb/snowflake"
      # >= 2.x required for snowflake_cortex_agent / preview_features_enabled
      # (not available in the 0.x series this was previously pinned to).
      # Major version jump from the prior 0.94-0.99 range — re-validate
      # every existing snowflake_* resource against this, not just the
      # new one, since provider major bumps can carry breaking schema
      # changes for resources that were already working.
      version = ">= 2.0, < 3.0"
    }
  }

  backend "s3" {
    # Account-specific values (bucket, key, region, profile) are gitignored —
    # see backend.hcl.example. Run:
    #   terraform init -backend-config=backend.hcl
    use_lockfile = true
    encrypt      = true
  }
}
