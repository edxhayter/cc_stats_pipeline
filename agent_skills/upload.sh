#!/usr/bin/env bash
# Upload the skill folders in agent_skills/ to an agent's AGENT_SKILLS stage
# (terraform/envs/prod/agent_skills.tf), replacing what's there so deleted
# skills and files disappear too. Agents read skills from the stage on
# demand, so this takes effect on the next question.
#
# Usage:
#   SNOWFLAKE_DATABASE=<db> agent_skills/upload.sh <schema> [-- SNOW_FLAGS...]
#
#   Eval twin: called by evals/cortex_agent/run_eval.sh before every run.
#   Live agent: SNOWFLAKE_DATABASE=<db> agent_skills/upload.sh CRICKET_SCORECARDS -- -c <connection>
#
# DRY_RUN=1 prints the SQL instead of running it.
set -euo pipefail

schema="${1:?usage: agent_skills/upload.sh <schema> [-- SNOW_FLAGS...]}"
shift
snow_flags=()
if [[ "${1:-}" == "--" ]]; then shift; snow_flags=("$@"); fi
: "${SNOWFLAKE_DATABASE:?set SNOWFLAKE_DATABASE to the database holding the agent schema}"
skills_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

snow_sql() {
  if [[ "${DRY_RUN:-}" == 1 ]]; then echo "[dry run] $*" >&2; return; fi
  snow sql ${snow_flags[@]+"${snow_flags[@]}"} --database "$SNOWFLAKE_DATABASE" --schema "$schema" "$@" >/dev/null
}

snow_sql -q "REMOVE @AGENT_SKILLS"
for skill in "$skills_dir"/*/; do
  name="$(basename "$skill")"
  [[ -f "$skill/SKILL.md" ]] || continue
  for file in "$skill"*; do
    [[ -f "$file" ]] || continue
    snow_sql -q "PUT 'file://${file}' @AGENT_SKILLS/${name}/ AUTO_COMPRESS = FALSE OVERWRITE = TRUE"
  done
  echo "Uploaded skill ${name} to ${schema}.AGENT_SKILLS"
done
