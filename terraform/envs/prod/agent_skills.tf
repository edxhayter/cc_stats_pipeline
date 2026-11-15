# Agent skills and web search.
#
# Skills live in agent_skills/<name>/ at the repo root (SKILL.md plus any
# supporting files). Agents read them on demand from an AGENT_SKILLS stage in
# their own schema, and Terraform writes every skill file onto that stage
# (COPY INTO from the file's contents, byte-for-byte), so a skill change
# shows up in `terraform plan` like any other agent change.
#
# The twin's and the live agent's skill files are separate resources so an
# experiment branch can update the twin alone:
#   terraform apply \
#     -target='snowflake_cortex_agent.cricket_scorecards_analyst["eval"]' \
#     -target=snowflake_execute.eval_agent_skill_file
# Merging promotes the skills with the rest of the spec on the next full
# apply from main.

locals {
  skills_dir  = "${path.module}/../../../agent_skills"
  skill_files = fileset(local.skills_dir, "*/*")
  skill_names = sort(distinct([for f in local.skill_files : dirname(f)]))

  # Writes a file's exact text to a stage path. Dollar-quoting keeps the
  # Markdown verbatim; the precondition below rejects files containing $$.
  skill_copy_sql = "COPY INTO %s FROM (SELECT $$%s$$) FILE_FORMAT = (TYPE = CSV COMPRESSION = NONE FIELD_DELIMITER = NONE RECORD_DELIMITER = NONE FIELD_OPTIONALLY_ENCLOSED_BY = NONE ESCAPE_UNENCLOSED_FIELD = NONE) SINGLE = TRUE HEADER = FALSE OVERWRITE = TRUE"
}

resource "snowflake_stage" "agent_skills" {
  for_each = local.cortex_agents

  name     = "AGENT_SKILLS"
  database = var.snowflake_database_name
  schema   = each.value.schema
  comment  = "Skills for ${each.value.name}, written by Terraform from agent_skills/ in the repo."
}

resource "snowflake_execute" "eval_agent_skill_file" {
  for_each = local.skill_files

  execute = format(local.skill_copy_sql, "@${snowflake_stage.agent_skills["eval"].fully_qualified_name}/${each.key}", file("${local.skills_dir}/${each.key}"))
  revert  = "REMOVE @${snowflake_stage.agent_skills["eval"].fully_qualified_name}/${each.key}"

  lifecycle {
    precondition {
      condition     = !strcontains(file("${local.skills_dir}/${each.key}"), "$$")
      error_message = "agent_skills/${each.key} contains $$, which would break the dollar-quoted write."
    }
  }
}

resource "snowflake_execute" "prod_agent_skill_file" {
  for_each = local.skill_files

  execute = format(local.skill_copy_sql, "@${snowflake_stage.agent_skills["prod"].fully_qualified_name}/${each.key}", file("${local.skills_dir}/${each.key}"))
  revert  = "REMOVE @${snowflake_stage.agent_skills["prod"].fully_qualified_name}/${each.key}"

  lifecycle {
    precondition {
      condition     = !strcontains(file("${local.skills_dir}/${each.key}"), "$$")
      error_message = "agent_skills/${each.key} contains $$, which would break the dollar-quoted write."
    }
  }
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
