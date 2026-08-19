terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = ">= 0.94, < 1.0"
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
