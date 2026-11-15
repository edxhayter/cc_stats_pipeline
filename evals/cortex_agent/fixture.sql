-- Frozen eval snapshot of the raw scorecard lines.
--
-- A zero-copy clone: it shares storage with the source table and never
-- sees later loads, so everything the dbt `eval` target builds on top of it
-- (and so the ground truth in eval_cases.sql) stays fixed. Schemas are
-- Terraform-managed (terraform/envs/prod/agent_evals.tf).
--
-- Run once. Re-running takes a NEW snapshot: only do that deliberately,
-- then rebuild the eval target, re-derive every ground truth answer and
-- bump the dataset version in eval_cases.sql and agent_evaluation_config.yaml.
--
-- Snapshot in use: 235 matches, 2026-04-03 to 2026-07-18 (latest load
-- 2026-11-15).

USE DATABASE IDENTIFIER($database_name);  -- SET database_name = '<DATABASE>'; first

CREATE TABLE CRICKET_SCORECARDS_EVAL_RAW.SCORECARD_LINES
    CLONE CRICKET_SCORECARDS_RAW.SCORECARD_LINES;

-- Sanity check: should match the snapshot noted above.
SELECT COUNT(DISTINCT source_file_name) AS matches,
       MAX(loaded_at)                   AS latest_load
FROM CRICKET_SCORECARDS_EVAL_RAW.SCORECARD_LINES;
