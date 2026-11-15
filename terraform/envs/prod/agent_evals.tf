# EXECUTE_AI_EVALUATION reads its config YAML
# (evals/cortex_agent/agent_evaluation_config.yaml) from a stage, and
# Snowflake requires an uncompressed file behind a CSV format with no
# delimiters so the YAML is read as-is. Lives with the agent; the eval
# datasets are data, created by evals/cortex_agent/eval_cases.sql.

resource "snowflake_file_format" "agent_eval_yaml" {
  name        = "AGENT_EVAL_YAML"
  database    = var.snowflake_database_name
  schema      = var.snowflake_semantic_schema
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
  schema   = var.snowflake_semantic_schema
  comment  = "Cortex Agent evaluation config YAML for CRICKET_SCORECARDS_ANALYST."

  file_format = "FORMAT_NAME = '${var.snowflake_database_name}.${var.snowflake_semantic_schema}.${snowflake_file_format.agent_eval_yaml.name}'"
}
