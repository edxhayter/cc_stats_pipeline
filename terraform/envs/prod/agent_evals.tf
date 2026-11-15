# Eval environment for the Cortex Agent.
#
# CRICKET_SCORECARDS_EVAL_RAW holds a zero-copy clone of the raw scorecard
# lines, taken once by evals/cortex_agent/fixture.sql. It shares storage
# with the source and never sees new loads, so the eval ground truth stays
# fixed. The dbt `eval` target rebuilds the project over it into
# CRICKET_SCORECARDS_EVAL, where the eval twin agent (cortex_agent.tf), the
# eval dataset and the config stage below also live.
#
# Terraform owns the schemas; the clone (data) and the dbt views are created
# outside Terraform. Destroying these schemas drops the snapshot.

resource "snowflake_schema" "eval_raw" {
  database = var.snowflake_database_name
  name     = "CRICKET_SCORECARDS_EVAL_RAW"
  comment  = "Frozen zero-copy clone of the raw scorecard lines for agent evals."
}

resource "snowflake_schema" "eval" {
  database = var.snowflake_database_name
  name     = "CRICKET_SCORECARDS_EVAL"
  comment  = "dbt eval target (views over the frozen clone), eval twin agent and eval datasets."
}

# EXECUTE_AI_EVALUATION reads its config YAML
# (evals/cortex_agent/agent_evaluation_config.yaml) from a stage, and
# Snowflake requires an uncompressed file behind a CSV format with no
# delimiters so the YAML is read as-is.

resource "snowflake_file_format" "agent_eval_yaml" {
  name        = "AGENT_EVAL_YAML"
  database    = var.snowflake_database_name
  schema      = snowflake_schema.eval.name
  format_type = "CSV"

  field_delimiter              = "NONE"
  record_delimiter             = "\n"
  skip_header                  = 0
  field_optionally_enclosed_by = "NONE"
  escape_unenclosed_field      = "NONE"
}

resource "snowflake_stage" "agent_eval_config" {
  name     = "AGENT_EVAL_CONFIG"
  database = var.snowflake_database_name
  schema   = snowflake_schema.eval.name
  comment  = "Cortex Agent evaluation config YAML for CRICKET_SCORECARDS_ANALYST_EVAL."

  file_format = "FORMAT_NAME = '${var.snowflake_database_name}.${snowflake_schema.eval.name}.${snowflake_file_format.agent_eval_yaml.name}'"
}
