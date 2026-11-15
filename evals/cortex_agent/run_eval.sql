-- Read the results of an evaluation run started by run_eval.sh.
--
-- Set run_name to the name run_eval.sh printed (also listed in Snowsight
-- under the agent's Evaluations tab), and run in the eval twin's schema.

USE SCHEMA CRICKET_SCORECARDS_EVAL;  -- USE DATABASE <DATABASE> first if needed
SET run_name = '<run name from run_eval.sh>';

-- 1. Status: CREATED → INVOCATION_* → COMPUTATION_* → COMPLETED.
CALL EXECUTE_AI_EVALUATION(
    'STATUS',
    OBJECT_CONSTRUCT('run_name', $run_name),
    '@agent_eval_config/agent_evaluation_config.yaml'
);

-- 2. Per-record results. Join back to the cases table for case_id/category.
SELECT c.case_id, c.category, r.metric_name, r.eval_agg_score, r.output
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    CURRENT_DATABASE(),
    CURRENT_SCHEMA(),
    'CRICKET_SCORECARDS_ANALYST_EVAL',
    'CORTEX AGENT',
    $run_name
)) r
LEFT JOIN cricket_agent_eval_cases c ON c.input_query = r.input
ORDER BY c.category, c.case_id, r.metric_name;

-- 3. Errors/warnings for the run, if any record failed to score.
SELECT timestamp, record:"severity_text"::STRING AS severity, value
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_LOGS(
    CURRENT_DATABASE(),
    CURRENT_SCHEMA(),
    'CRICKET_SCORECARDS_ANALYST_EVAL',
    'CORTEX AGENT'
))
WHERE (record:"severity_text" = 'ERROR' OR record:"severity_text" = 'WARN')
  AND record_attributes:"snow.ai.observability.run.name" = $run_name
ORDER BY timestamp;
