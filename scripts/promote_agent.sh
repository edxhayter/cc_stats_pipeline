#!/usr/bin/env bash
# Promote CRICKET_SCORECARDS_ANALYST's LIVE (draft) version to what users get.
#
# Terraform edits LIVE; Snowsight, CoWork and the API serve the DEFAULT
# committed version. After an apply has been evaluated
# (evals/cortex_agent/run_eval.sh), this commits LIVE as the next VERSION$N,
# makes it DEFAULT, and opens a fresh LIVE draft from it for Terraform to
# edit next (committing doesn't create one). Roll back with
#   ALTER AGENT ... SET DEFAULT_VERSION = 'VERSION$<n>';
#
# Run once before the first Terraform apply that uses versions, too: it
# freezes what users currently get as a committed DEFAULT, so later applies
# to LIVE don't reach them until promoted.
#
# Usage:
#   SNOWFLAKE_DATABASE=<db> scripts/promote_agent.sh [-- SNOW_FLAGS...]
# SNOWFLAKE_SCHEMA is the agent's schema (default CRICKET_SCORECARDS).
# DRY_RUN=1 prints the SQL instead of running it.
set -euo pipefail

snow_flags=()
if [[ "${1:-}" == "--" ]]; then shift; snow_flags=("$@"); fi
: "${SNOWFLAKE_DATABASE:?set SNOWFLAKE_DATABASE to the database holding the agent}"
schema="${SNOWFLAKE_SCHEMA:-CRICKET_SCORECARDS}"
agent="CRICKET_SCORECARDS_ANALYST"

snow_sql() {
  if [[ "${DRY_RUN:-}" == 1 ]]; then echo "[dry run] $*" >&2; return; fi
  snow sql ${snow_flags[@]+"${snow_flags[@]}"} --database "$SNOWFLAKE_DATABASE" --schema "$schema" "$@"
}

snow_sql -q "ALTER AGENT ${agent} COMMIT" >/dev/null
snow_sql -q "ALTER AGENT ${agent} SET DEFAULT_VERSION = LAST" >/dev/null
snow_sql -q "ALTER AGENT ${agent} ADD LIVE VERSION FROM LAST" >/dev/null
snow_sql -q "SHOW VERSIONS IN AGENT ${agent}"
