# Cortex Agent evals

Evaluates the cricket scorecards agent with Snowflake's native
[Cortex Agent evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)
(`EXECUTE_AI_EVALUATION`). Results show up in Snowsight under the agent's
**Evaluations** tab as well as via SQL.

Evals run against `CRICKET_SCORECARDS_ANALYST_EVAL`, a twin of the live
agent built from the same Terraform definition. It reads a semantic view
built over a frozen snapshot of the data, so the expected answers never
drift as new scorecards land, and agent experiments don't touch the live
agent.

| File | What it is |
|---|---|
| `fixture.sql` | One-off zero-copy clone of the raw scorecard lines into `CRICKET_SCORECARDS_EVAL_RAW` |
| `eval_cases.sql` | Eval table + 21 cases with ground truth, then creates dataset `CRICKET_AGENT_EVALSET_V1` |
| `agent_evaluation_config.yaml` | Which agent, which dataset, which metrics |
| `run_eval.sql` | Upload config, start a run, poll, read results |
| `../../terraform/envs/prod/agent_evals.tf` | Eval schemas, stage + file format the config is read from |
| `../../terraform/envs/prod/cortex_agent.tf` | Live agent and its eval twin |

## How the snapshot works

```
CRICKET_SCORECARDS_RAW ──clone (once)──► CRICKET_SCORECARDS_EVAL_RAW
                                              │  dbt build --target eval
                                              ▼
                       CRICKET_SCORECARDS_EVAL: marts + SV_CRICKET_SCORECARDS
                                              │
                                              ▼
                              CRICKET_SCORECARDS_ANALYST_EVAL (twin agent)
```

The clone shares storage with the source and never sees later loads. The
dbt `eval` target rebuilds the whole project over it, so a dbt or semantic
view change that shifts an answer shows up as an eval failure.

Snapshot in use: **235 matches, 3 April to 18 July 2026**. "This season"
in the cases means that range.

## Cases

- **verified_query (9)** — mirror the `AI_VERIFIED_QUERIES` in
  `sv_cricket_scorecards.sql`. Should pass; a failure here means something
  is broken, not that the agent is weak.
- **held_out_season / held_out_match (7)** — no verified query covers
  them. These are the real measure of how well the semantic view
  generalises. Includes a pooled season Match Factor question.
- **name_resolution (2)** — surname only. "Gubbins" has one match;
  "Ali" has four, and the sim's top-scoring Ali (K Ali) isn't the one
  sharing a famous real-world name (M Ali).
- **out_of_scope (3)** — toss, venue, ball-by-ball. The agent should say
  the data doesn't exist and not call the tool.

Ground truth comes from the eval marts only, never the raw scorecards: the
evals score the agent against what the marts say, and parsing bugs are for
the dbt tests to catch. Match Factor over a period is the pooled metric,
not an average of per-match factors.

## Running

1. `terraform apply` creates the eval schemas, twin agent and stage
   (one-off).
2. Run `fixture.sql` once to take the snapshot, then
   `dbt build --target eval`.
3. Run `eval_cases.sql` once (set `agent_schema_fqn` at the top).
4. Run `run_eval.sql` from SnowSQL or the Snowflake CLI (`PUT` needs a
   client). Re-run step 4 on any agent or semantic view change, after
   rebuilding the eval target.

**Changing cases:** datasets are immutable. Edit the rows, bump `_V1` →
`_V2` in both `eval_cases.sql` and `agent_evaluation_config.yaml`, rerun
step 3.

**New snapshot:** only deliberately. Re-run `fixture.sql` (replacing the
clone), rebuild the eval target, re-derive every answer from the eval
marts, and bump the dataset version.

**Privileges** (running role): a Cortex database role (e.g.
`SNOWFLAKE.CORTEX_USER`), `EXECUTE TASK ON ACCOUNT`, `CREATE DATASET` and
`CREATE TABLE` on the schema, `USAGE` + `MONITOR` on the agent, `READ` on
the stage, and access to the semantic view.

**Reading scores:** agent orchestration is non-deterministic. Run the
dataset 2–3 times to find its normal range before treating a single drop
as a regression. `answer_correctness` is the most stable metric;
`tool_selection_accuracy` and `logical_consistency` move when the agent
takes a different path.
