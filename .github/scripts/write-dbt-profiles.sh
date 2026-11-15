#!/usr/bin/env bash
# Writes dbt_projects_profiles.yml for dbt Projects on Snowflake (which
# reads it in preference to profiles.yml). Generated at deploy time from
# GitHub variables so the account-specific database name never lands in
# tracked code. account/user are placeholders: the dbt project object runs
# as the deploying Snowflake session, not with these credentials.
set -euo pipefail

: "${SNOWFLAKE_DATABASE:?}" "${SNOWFLAKE_WAREHOUSE:?}" "${SNOWFLAKE_ROLE:?}"
schema="${SNOWFLAKE_SEMANTIC_SCHEMA:-${SNOWFLAKE_SCHEMA:?}}"

target() {
  cat <<YAML
    $1:
      type: snowflake
      account: '_'
      user: '_'
      role: ${SNOWFLAKE_ROLE}
      database: ${SNOWFLAKE_DATABASE}
      warehouse: ${SNOWFLAKE_WAREHOUSE}
      schema: $2
      threads: 8
YAML
}

{
  echo "cc_scorecard_transform:"
  echo "  target: prod"
  echo "  outputs:"
  target prod "${schema}"
} > dbt/cc_scorecard_transform/dbt_projects_profiles.yml

echo "Wrote dbt_projects_profiles.yml (prod: ${schema})"
