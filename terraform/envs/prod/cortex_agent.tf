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
# Two agents from one definition: `prod` reads the live semantic view;
# `eval` reads the semantic view the dbt `eval` target builds over a frozen
# clone of the raw data (see agent_evals.tf), so eval ground truth never
# drifts. Keeping both in one for_each means they can't diverge by accident.
#
# Both agents render the same spec (agent_spec.yaml.tftpl): instructions,
# tools and the orchestration model live there and in git, nowhere else.
# To try a change, edit it on a branch and apply it to the twin only:
#   terraform apply -target='snowflake_cortex_agent.cricket_scorecards_analyst["eval"]'
# then run evals/cortex_agent/run_eval.sh (runs are named after the commit).
# Merging promotes it: the next full apply from main updates the live agent.
# Until then, a full apply from main puts the twin back on main's spec.
# Record each experiment's before/after scores in its PR description.

locals {
  cortex_agents = {
    prod = {
      name         = "CRICKET_SCORECARDS_ANALYST"
      schema       = var.snowflake_semantic_schema
      display_name = "Cricket Scorecards Analyst"
    }
    eval = {
      name         = "CRICKET_SCORECARDS_ANALYST_EVAL"
      schema       = snowflake_schema.eval.name
      display_name = "Cricket Scorecards Analyst (eval)"
    }
  }
}

moved {
  from = snowflake_cortex_agent.cricket_scorecards_analyst
  to   = snowflake_cortex_agent.cricket_scorecards_analyst["prod"]
}

resource "snowflake_cortex_agent" "cricket_scorecards_analyst" {
  for_each = local.cortex_agents

  database = var.snowflake_database_name
  schema   = each.value.schema
  name     = each.value.name
  comment  = "Cricket statistics analyst — answers batting/bowling/match questions via the cricket scorecards semantic view."

  profile {
    display_name = each.value.display_name
  }

  specification = templatefile("${path.module}/agent_spec.yaml.tftpl", {
    # null omits `models`, so Snowflake picks the model (`auto`).
    orchestration_model = null
    semantic_view       = "${var.snowflake_database_name}.${each.value.schema}.SV_CRICKET_SCORECARDS"
    warehouse           = var.snowflake_warehouse_name
    # Every agent_skills/<name>/SKILL.md in the repo, read from this agent's
    # own skills stage (agent_skills.tf).
    skills       = sort([for f in fileset("${path.module}/../../../agent_skills", "*/SKILL.md") : dirname(f)])
    skills_stage = "@${var.snowflake_database_name}.${each.value.schema}.${snowflake_stage.agent_skills[each.key].name}"
  })
}
