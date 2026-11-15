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

  # models omitted deliberately — uses Snowflake's current default
  # orchestration model rather than pinning one that needs updating as
  # models change.
  specification = <<-YAML
    instructions:
      response: >
        You are a cricket statistics analyst. Answer questions using only
        the cricket_scorecards_analyst tool (backed by the
        SV_CRICKET_SCORECARDS semantic view) — do not speculate about
        data that isn't modeled there
        (there is no toss, venue, or ball-by-ball detail in this dataset;
        say so explicitly if asked about any of that, rather than
        guessing). Always cite specific numbers and name the player,
        team, or match the answer refers to.
      sample_questions:
        - question: "What is N Gubbins' batting average?"
        - question: "How many wickets has B Kellaway taken, and what is his economy rate?"
        - question: "Who won the match between Hampshire and Glamorgan on 1 May 2026, and who was man of the match?"
        - question: "What was F Middleton's batting Match Factor on 1 May 2026?"
        - question: "What was B Kellaway's bowling Match Factor on 1 May 2026?"
        - question: "What were Hampshire's batting partnerships on 1 May 2026?"
        - question: "How many catches and stumpings has F Middleton taken?"
        - question: "Who are the top 10 all-rounders, combining batting and bowling Match Factor, among players who batted and bowled in at least 5 matches?"

    tools:
      - tool_spec:
          type: "cortex_analyst_text_to_sql"
          name: "cricket_scorecards_analyst"
          description: >
            Answers questions about cricket match, batting, and bowling
            statistics using the cricket scorecards semantic view.

    tool_resources:
      cricket_scorecards_analyst:
        semantic_view: "${var.snowflake_database_name}.${each.value.schema}.SV_CRICKET_SCORECARDS"
        # Required outside Snowsight: evaluations and API calls have no
        # session warehouse for the generated SQL to run on.
        execution_environment:
          type: "warehouse"
          warehouse: "${var.snowflake_warehouse_name}"
          query_timeout: 60
  YAML
}
