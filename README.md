# Cricket Scorecard Data Pipeline

Ingests raw `.txt` cricket scorecards from a local landing folder into
Snowflake, parses them into a structured star schema, and serves BI
(individual player + team views) and conversational analytics via Cortex
Analyst. Infra is managed with Terraform; transformation with dbt.

## Architecture

![Pipeline architecture](pipeline-architecture-aws.drawio.png)

**Flow:** a local `launchd` job syncs scorecard files to an encrypted S3
bucket → a Snowflake storage integration/external stage reads from that
bucket → a scheduled Snowflake Task runs `COPY INTO` a raw table → a
second Task (`AFTER` the first) runs `dbt build` natively inside Snowflake
→ staging models parse the raw text with SQL → marts feed a BI tool and a
Snowflake Semantic View → the semantic view powers Cortex Analyst.

No external orchestrator (Airflow, Step Functions) — see [Decisions](#decisions).

## CI/CD

![CI/CD flow](cicd-flow-aws.drawio.png)

Two independent pipelines, both triggered on merge to `main`:

1. **Infra pipeline** — `terraform apply` (S3 backend, native locking) updates AWS + Snowflake objects.
2. **dbt deploy pipeline** — Snowflake CLI pushes the dbt project into the `DBT PROJECT` object; the next scheduled Task run picks up the new version automatically.

Every MR runs `terraform plan` + `dbt compile/test` (dev schema) first, with output posted for review before merge.

## Decisions

| Area | Decision | Why |
|---|---|---|
| Local → S3 push | `launchd` agent with `WatchPaths` (not a fixed interval) | Fires immediately when a new scorecard file lands, no polling delay |
| AWS auth (uploader) | IAM user + scoped policy in Terraform; access key created out-of-band (`aws iam create-access-key`), stored in a gitignored local `.env` | Keeps the secret out of Terraform state entirely; rotation is manual (delete/recreate the key, update `.env`) |
| Object encryption | Upload script sends `--sse aws:kms` but never a specific key ID | The bucket's own default-encryption CMK is the single source of truth for which key is used — the script can't drift out of sync if the key is ever rotated |
| Terraform state locking | S3 native (`use_lockfile=true`), no DynamoDB | GA since Terraform 1.11 — one less resource, smaller IAM surface |
| Snowflake database | Existing database referenced by variable (see `terraform.tfvars`, gitignored); only a new `CRICKET_SCORECARDS_RAW` schema is created | Avoids Terraform owning a shared database it has no reason to manage, and avoids hardcoding an account-specific name in tracked code |
| Ingestion trigger | Scheduled `COPY INTO` via Snowflake Task (not Snowpipe), daily | Matches batch framing (scorecards arrive in batches, not continuously); no SQS/event infra |
| Warehouse | Existing warehouse referenced, not created | Already provisioned |
| Raw file parsing | Pure SQL in dbt (gaps-and-islands + regex), not Python/Snowpark | Prototyped and validated against a real sample file |
| dbt hosting | **dbt Projects on Snowflake** (native, GA Nov 2025) | No Fargate/ECR/container infra; scheduled via `EXECUTE DBT PROJECT` |
| Semantic layer | Snowflake Semantic Views via `dbt_semantic_view` package | Free, native, what Cortex Analyst actually reads |
| Orchestration | None — Snowflake Task `AFTER` dependencies only | Two dependent steps in one system don't justify Airflow/Step Functions; MWAA runs ~24/7 regardless of load (~$358/mo base) |
| CI/CD | Two independent pipelines (infra via Terraform, dbt via Snowflake CLI) | Different systems, different failure domains — shouldn't block each other |

## Terraform resources

**AWS — implemented**
- `aws_s3_bucket` (+ versioning, public access block)
- `aws_kms_key` / `aws_kms_alias` (customer-managed key)
- `aws_s3_bucket_server_side_encryption_configuration` (default SSE-KMS)
- `aws_s3_bucket_policy` (deny non-TLS / non-KMS)
- `aws_iam_user` + scoped policy (uploader) — access key deliberately *not* managed here, see [Decisions](#decisions)
- `aws_iam_role` trusted by the Snowflake storage integration (two-pass apply — see `terraform/modules/snowflake-ingest/main.tf`)
- Backend: S3 with `use_lockfile = true`

**Snowflake — implemented**
- `snowflake_schema` (`CRICKET_SCORECARDS_RAW`) inside an existing database (referenced by variable, not hardcoded)
- `snowflake_storage_integration` + `snowflake_stage`
- `snowflake_file_format` (`FIELD_DELIMITER = 'NONE'` — whole line as one column)
- `snowflake_table` for `CRICKET_SCORECARDS_RAW.SCORECARD_LINES`
- `snowflake_task` (load task — daily `COPY INTO`)

**Snowflake — planned, not yet built**
- `snowflake_task` (dbt task — `AFTER` the load task)
- External access integration (for `dbt deps`)
- `snowflake_role` + grants (loader / dbt / BI-agent readers, separated)

## dbt project

- **Sources:** `CRICKET_SCORECARDS_RAW.SCORECARD_LINES`
- **Staging (SQL only):**
  - `stg_blocks` — gaps-and-islands block segmentation
  - `stg_row_classification` — row-type detection
  - `stg_batting`, `stg_bowling` — validated against a real sample file
  - `stg_fow` — fall-of-wickets; wraps across lines, needs `LISTAGG`-then-split (not yet built)
  - `stg_match_header` / `stg_result`
- **Marts (star schema):** `dim_player`, `dim_team`, `dim_match`, `fact_batting`, `fact_bowling`, `fact_fow`
- **Semantic layer:** `dbt_semantic_view` definitions feeding Cortex Analyst — include verified query examples for the batting/bowling questions expected most

## Open items

- Confirm player name consistency across matches before finalizing `dim_player`
- Build `stg_fow` (multi-line wrap logic)
- CI/CD auth: OIDC federation for the infra pipeline, Snowflake key-pair service user for the dbt deploy pipeline
- Cortex Analyst rollout: start narrow (batting/bowling + one team view), expand once accuracy is validated

## Build order

1. ~~AWS module (S3 + KMS + IAM) — confirm local sync end to end~~ ✅
2. ~~Snowflake ingestion module (storage integration, stage, file format, raw table, load task)~~ ✅
3. dbt staging models — finish `stg_fow`, validate against a larger sample set
4. dbt marts
5. dbt task, chained `AFTER` the load task
6. Semantic views + Cortex Analyst rollout
7. BI tool connection
8. CI/CD pipelines (MR checks, infra apply, dbt deploy)
