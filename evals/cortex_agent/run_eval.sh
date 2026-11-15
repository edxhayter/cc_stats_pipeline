#!/usr/bin/env bash
# Start a Cortex Agent evaluation run against the eval twin agent
# (CRICKET_SCORECARDS_ANALYST_EVAL), naming the run after what's being tested.
#
# Run name: <label>-<git short sha>[-dirty]-<UTC timestamp>, e.g.
#   baseline-9e35736-20261115-163000. "-dirty" marks uncommitted changes, so a
#   score can always be traced back to the code that produced it.
#
# Steps: create the eval dataset if its version is new (eval_cases.sql),
# upload the config, START the run, and with --wait poll until it finishes.
#
# Usage:
#   SNOWFLAKE_DATABASE=<db> evals/cortex_agent/run_eval.sh [--label NAME] [--wait] [-- SNOW_FLAGS...]
#
#   Local:  SNOWFLAKE_DATABASE=<db> evals/cortex_agent/run_eval.sh --label baseline --wait -- -c <connection>
#   CI:     evals/cortex_agent/run_eval.sh --label deploy -- -x
#
# SNOW_FLAGS are passed to every `snow sql` call (connection selection).
# EVAL_SCHEMA overrides the schema (default CRICKET_SCORECARDS_EVAL).
# DRY_RUN=1 prints the SQL instead of running it.
set -euo pipefail

label="manual"
wait=false
snow_flags=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label="$2"; shift 2 ;;
    --wait) wait=true; shift ;;
    --) shift; snow_flags=("$@"); break ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

: "${SNOWFLAKE_DATABASE:?set SNOWFLAKE_DATABASE to the database holding the eval schema}"
schema="${EVAL_SCHEMA:-CRICKET_SCORECARDS_EVAL}"
eval_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="$eval_dir/agent_evaluation_config.yaml"
cases="$eval_dir/eval_cases.sql"
stage_file="@AGENT_EVAL_CONFIG/agent_evaluation_config.yaml"
poll_seconds=30
timeout_seconds=2700

sha="$(git -C "$eval_dir" rev-parse --short=7 HEAD)"
git -C "$eval_dir" diff --quiet HEAD || sha="${sha}-dirty"
run_name="${label}-${sha}-$(date -u +%Y%m%d-%H%M%S)"

snow_sql() {
  if [[ "${DRY_RUN:-}" == 1 ]]; then
    echo "[dry run] $*" >&2
    case "$*" in
      *"SHOW DATASETS"*) echo "[]" ;;
      *"'STATUS'"*) echo '[{"STATUS": "COMPLETED"}]' ;;
    esac
    return
  fi
  snow sql ${snow_flags[@]+"${snow_flags[@]}"} --database "$SNOWFLAKE_DATABASE" --schema "$schema" "$@"
}

# Datasets are immutable, so a new _V<n> in the config means a new dataset.
dataset="$(sed -n 's/^ *dataset_name: *"\([A-Z0-9_]*\)".*/\1/p' "$config")"
if ! grep -q "\.${dataset}'" "$cases"; then
  echo "eval_cases.sql doesn't create ${dataset}; bump the version in both files together" >&2
  exit 1
fi
if [[ "$(snow_sql --format json -q "SHOW DATASETS LIKE '${dataset}' IN SCHEMA" | jq length)" -eq 0 ]]; then
  echo "Creating dataset ${dataset}"
  snow_sql -f "$cases" >/dev/null
fi

snow_sql -q "PUT 'file://${config}' @AGENT_EVAL_CONFIG AUTO_COMPRESS = FALSE OVERWRITE = TRUE" >/dev/null
snow_sql -q "CALL EXECUTE_AI_EVALUATION('START', OBJECT_CONSTRUCT('run_name', '${run_name}'), '${stage_file}')" >/dev/null
echo "Started ${run_name}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Agent evals started"
    echo
    echo "Run \`${run_name}\` is scoring in Snowflake. Results: Snowsight → AI & ML → Agents → CRICKET_SCORECARDS_ANALYST_EVAL → Evaluations."
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ "$wait" == true ]]; then
  deadline=$(( $(date +%s) + timeout_seconds ))
  last=""
  while :; do
    status="$(snow_sql --format json -q "CALL EXECUTE_AI_EVALUATION('STATUS', OBJECT_CONSTRUCT('run_name', '${run_name}'), '${stage_file}')" | jq -r '.[0].STATUS')"
    [[ "$status" != "$last" ]] && echo "$(date -u +%H:%M:%S) ${status}" && last="$status"
    case "$status" in
      COMPLETED | PARTIALLY_COMPLETED) break ;;
      FAILED | CANCELLED) echo "Run ${run_name} ended ${status}; see GET_AI_OBSERVABILITY_LOGS in run_eval.sql" >&2; exit 1 ;;
    esac
    if (( $(date +%s) > deadline )); then
      echo "Run ${run_name} still ${status} after ${timeout_seconds}s; it keeps running in Snowflake" >&2
      exit 1
    fi
    sleep "$poll_seconds"
  done

  # Scores per metric, plus speed and size per question (duration and tokens
  # repeat across a record's metric rows, so take one per record).
  snow_sql --format json -q "
    WITH d AS (
      SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
        CURRENT_DATABASE(), CURRENT_SCHEMA(), 'CRICKET_SCORECARDS_ANALYST_EVAL', 'CORTEX AGENT', '${run_name}'))
    ), rec AS (
      SELECT record_id, ANY_VALUE(duration_ms) AS ms, ANY_VALUE(total_input_tokens) AS tok
      FROM d GROUP BY record_id
    )
    SELECT metric_name AS measure, ROUND(AVG(eval_agg_score), 3) AS value FROM d GROUP BY 1
    UNION ALL SELECT 'avg_seconds_per_question', ROUND(AVG(ms) / 1000, 1) FROM rec
    UNION ALL SELECT 'avg_input_tokens_per_question', ROUND(AVG(tok)) FROM rec
    ORDER BY 1" | jq -r '.[] | "  \(.MEASURE): \(.VALUE)"'
fi

echo "$run_name"
