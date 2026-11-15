# Agent skills and web search.
#
# Skills (agent_skills/<name>/SKILL.md at the repo root) are read by the
# agent from a stage in its own schema, on demand, so each agent gets the
# skill files uploaded for it: run_eval.sh uploads the checked-out files to
# the eval twin's stage before every run, and the deploy uploads main's to
# the live agent's (agent_skills/upload.sh). Terraform owns the stages; the
# files are content, not infrastructure.

resource "snowflake_stage" "agent_skills" {
  for_each = local.cortex_agents

  name     = "AGENT_SKILLS"
  database = var.snowflake_database_name
  schema   = each.value.schema
  comment  = "SKILL.md packages for ${each.value.name} (agent_skills/ in the repo)."
}

# Web search is switched on account-wide (AI & ML > Agents > Settings, which
# sets ENABLE_CORTEX_WEBSEARCH). It's a shared-account setting needing
# ACCOUNTADMIN, so this project checks it rather than owning it — a destroy
# here must never turn web search off for everyone. Plan warns if it's off.
data "snowflake_parameters" "web_search" {
  parameter_type = "ACCOUNT"
  pattern        = "ENABLE_CORTEX_WEBSEARCH"
}

check "web_search_enabled" {
  assert {
    condition = anytrue([
      for p in data.snowflake_parameters.web_search.parameters :
      p.key == "ENABLE_CORTEX_WEBSEARCH" && upper(p.value) == "TRUE"
    ])
    error_message = "Web search is off for this Snowflake account, so the agent's web_search tool will fail. An ACCOUNTADMIN can enable it in Snowsight: AI & ML > Agents > Settings > Web search."
  }
}
