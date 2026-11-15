# CI/CD

GitHub Actions, two workflows:

| Workflow | Trigger | Does |
|---|---|---|
| `pr-checks.yml` | PR to `main` | `terraform fmt/validate/plan` (plan in the job summary); `dbt parse` |
| `deploy.yml` | push to `main`, manual | `terraform apply` and dbt deploy + build in parallel, then starts the agent evals in Snowflake |

```
PR ──► terraform plan
   └─► dbt parse (no Snowflake connection)

merge ──► terraform apply ───────────────┐
      └─► dbt deploy ─► dbt build prod ──┴─► start agent evals (report-only)
```

PRs only parse the dbt project; models and tests run for real on merge,
so a model that fails at runtime fails the deploy (and skips the evals)
rather than the PR. Fine for a single-maintainer project; add a slim CI
build if that changes.

Evals run entirely in Snowflake (`EXECUTE_AI_EVALUATION`). The deploy job
creates the dataset if its version is new, uploads the config, starts the
run and exits — it doesn't wait. Scores are in Snowsight under the agent's
**Evaluations** tab, or via `evals/cortex_agent/run_eval.sql`. A low score
never fails the deploy.

## Identities

| Where | Identity | Auth |
|---|---|---|
| AWS, PR plan | `gha-cc-stats-terraform-plan` — read-only + state | GitHub OIDC, any `pull_request` in this repo |
| AWS, deploy | `gha-cc-stats-terraform-apply` — read-only + state + project bucket/KMS/IAM principals | GitHub OIDC, `production` environment only |
| Snowflake, everything | `CC_STATS_GITHUB_ACTIONS` service user, granted `var.snowflake_role` | Key pair |

All defined in `terraform/envs/prod/ci.tf`. The apply role has no IAM
rights over the `gha-*` roles, so CI can't widen its own access — changes
to `ci.tf`'s roles need a local apply.

Snowflake uses a key pair rather than workload identity federation because
`snowflake_service_user` can't set `WORKLOAD_IDENTITY` yet and Terraform's
provider already authenticates by key. Revisit once the provider supports it.

## One-off bootstrap

CI can't create the identities it runs as, so this happens locally once.

1. Generate the CI key pair (encrypted — the workflows expect a passphrase):
   ```sh
   openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes256 -inform PEM -out ci_key.p8
   openssl rsa -in ci_key.p8 -pubout -out ci_key.pub
   ```
   Keep both out of the repo (`*.p8` / `*.pub` are gitignored).
2. In `terraform.tfvars` set `tf_state_bucket_name` and
   `ci_snowflake_rsa_public_key` (the `.pub` body without BEGIN/END
   lines). If this AWS account already has a GitHub OIDC provider, set
   `create_github_oidc_provider = false`.
3. `terraform apply` locally. Creating the external access integration
   needs a role with `CREATE INTEGRATION` on the account.
4. Create a `production` environment in the repo settings and add
   required reviewers — it's the gate on every apply.
5. Add the variables and secrets below.

## GitHub variables and secrets

Repository **variables** (Settings → Secrets and variables → Actions):

| Name | Value |
|---|---|
| `AWS_REGION` | e.g. `eu-west-2` |
| `AWS_PLAN_ROLE_ARN` | `terraform output gha_terraform_plan_role_arn` |
| `AWS_APPLY_ROLE_ARN` | `terraform output gha_terraform_apply_role_arn` (can live on the `production` environment instead) |
| `TF_STATE_BUCKET` | `backend.hcl` `bucket` |
| `TF_STATE_KEY` | `backend.hcl` `key` |
| `LANDING_BUCKET_NAME` | `terraform.tfvars` |
| `SNOWFLAKE_ORGANIZATION_NAME` | `terraform.tfvars` |
| `SNOWFLAKE_ACCOUNT_NAME` | `terraform.tfvars` |
| `SNOWFLAKE_CI_USER` | `CC_STATS_GITHUB_ACTIONS` |
| `SNOWFLAKE_CI_RSA_PUBLIC_KEY` | same value as the tfvar |
| `SNOWFLAKE_ROLE` | `terraform.tfvars` |
| `SNOWFLAKE_WAREHOUSE` | `terraform.tfvars` |
| `SNOWFLAKE_DATABASE` | `terraform.tfvars` |
| `SNOWFLAKE_SEMANTIC_SCHEMA` | e.g. `CRICKET_SCORECARDS` |
| `SNOWFLAKE_STORAGE_AWS_IAM_USER_ARN` | second-pass value from `terraform.tfvars` |
| `SNOWFLAKE_STORAGE_AWS_EXTERNAL_ID` | second-pass value from `terraform.tfvars` |

Repository **secrets**:

| Name | Value |
|---|---|
| `SNOWFLAKE_PRIVATE_KEY` | contents of `ci_key.p8` |
| `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` | its passphrase |

## Notes

- **dbt profile**: dbt Projects on Snowflake reads
  `dbt_projects_profiles.yml`, generated in CI by
  `.github/scripts/write-dbt-profiles.sh` so the database name stays out
  of tracked code. Local dbt keeps using your own `profiles.yml`.
- **Provider preview flags**: `providers.tf` enables the 2.x provider's
  preview gates for the stage/file format/table/storage integration
  resources the ingest module uses, as well as the new network rule and
  external access integration. Expect the first CI plan to be the first
  2.x plan of those resources — check it for drift before merging.
