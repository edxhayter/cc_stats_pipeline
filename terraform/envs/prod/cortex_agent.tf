# Cortex Agent — deliberately Terraform's responsibility, not dbt's.
# Unlike the semantic view (built directly on mart column structure, owned
# by dbt via the Snowflake-Labs/dbt_semantic_view package — see
# dbt/cc_scorecard_transform/models/semantic/), the agent is a thin config
# object: model choice, tool references, instructions, sample questions.
# It references the semantic view by name only, with no dependency on its
# internal column structure, so it doesn't need to live alongside the
# marts it points at. See docs/dbt-modeling-plan.md "Cortex Agent" section.
#
# Preview feature — requires preview_features_enabled on the provider
# (see providers.tf).
#
# The spec (agent_spec.yaml.tftpl) holds the instructions, tools, skills
# and orchestration model; it lives in git and nowhere else.
#
# Versions: Terraform edits the agent's LIVE (draft) version. Users in
# Snowsight, CoWork and the API get the DEFAULT committed version, and the
# evals target LIVE (evals/cortex_agent/agent_evaluation_config.yaml). So a
# change goes: apply (LIVE) -> run_eval.sh -> promote_agent.sh (commit LIVE,
# make it DEFAULT). Record each change's before/after scores in its PR.

moved {
  from = snowflake_cortex_agent.cricket_scorecards_analyst["prod"]
  to   = snowflake_cortex_agent.cricket_scorecards_analyst
}

resource "snowflake_cortex_agent" "cricket_scorecards_analyst" {
  database = var.snowflake_database_name
  schema   = var.snowflake_semantic_schema
  name     = "CRICKET_SCORECARDS_ANALYST"
  comment  = "Cricket statistics analyst — answers batting/bowling/match questions via the cricket scorecards semantic view."

  profile {
    display_name = "Cricket Scorecards Analyst"
  }

  specification = templatefile("${path.module}/agent_spec.yaml.tftpl", {
    # null omits `models`, so Snowflake picks the model (`auto`).
    orchestration_model = null
    semantic_view       = "${var.snowflake_database_name}.${var.snowflake_semantic_schema}.SV_CRICKET_SCORECARDS"
    warehouse           = var.snowflake_warehouse_name
    # Every skill folder in agent_skills/, read from the skills stage
    # (agent_skills.tf).
    skills       = local.skill_names
    skills_stage = "@${var.snowflake_database_name}.${var.snowflake_semantic_schema}.${snowflake_stage.agent_skills.name}"
  })
}
