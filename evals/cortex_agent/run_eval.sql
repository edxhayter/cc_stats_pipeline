-- Start, monitor, and read a Cortex Agent evaluation run.
-- Run from SnowSQL / Snowflake CLI (PUT needs a client, not Snowsight
-- worksheets — in Snowsight, upload the YAML to the stage via the UI).

SET agent_schema_fqn = '<DATABASE>.<SEMANTIC_SCHEMA>';  -- same schema as the agent
SET run_name = 'run-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD-HH24MISS');
USE SCHEMA IDENTIFIER($agent_schema_fqn);

-- 1. Upload the config (stage + file format are Terraform-managed, see
--    terraform/envs/prod/agent_evals.tf). Path is relative to the repo root.
PUT file://evals/cortex_agent/agent_evaluation_config.yaml @agent_eval_config
    AUTO_COMPRESS = FALSE
    OVERWRITE = TRUE;

-- 2. Start the run.
CALL EXECUTE_AI_EVALUATION(
    'START',
    OBJECT_CONSTRUCT('run_name', $run_name),
    '@agent_eval_config/agent_evaluation_config.yaml'
);

-- 3. Poll until complete.
CALL EXECUTE_AI_EVALUATION(
    'STATUS',
    OBJECT_CONSTRUCT('run_name', $run_name),
    '@agent_eval_config/agent_evaluation_config.yaml'
);

-- 4. Per-record results. Join back to the cases table for case_id/category.
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    CURRENT_DATABASE(),
    CURRENT_SCHEMA(),
    'CRICKET_SCORECARDS_ANALYST',
    'CORTEX AGENT',
    $run_name
));

-- 5. Errors/warnings for the run, if any record failed to score.
SELECT *
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_LOGS(
    CURRENT_DATABASE(),
    CURRENT_SCHEMA(),
    'CRICKET_SCORECARDS_ANALYST',
    'CORTEX AGENT'
))
WHERE (record:"severity_text" = 'ERROR' OR record:"severity_text" = 'WARN')
  AND record_attributes:"snow.ai.observability.run.name" = $run_name;
