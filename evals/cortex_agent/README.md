# Cortex Agent evals

Evaluates `CRICKET_SCORECARDS_ANALYST` with Snowflake's native
[Cortex Agent evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)
(`EXECUTE_AI_EVALUATION`). Results show up in Snowsight under the agent's
**Evaluations** tab as well as via SQL.

| File | What it is |
|---|---|
| `eval_cases.sql` | Eval table + 18 cases with ground truth, then creates dataset `CRICKET_AGENT_EVALSET_V1` |
| `agent_evaluation_config.yaml` | Which agent, which dataset, which metrics |
| `run_eval.sql` | Start, poll and read a run by hand |
| `../../terraform/envs/prod/agent_evals.tf` | Stage + file format the config is read from |

## Cases

- **verified_query (9)** — mirror the `AI_VERIFIED_QUERIES` in
  `sv_cricket_scorecards.sql`. Should pass; a failure here means something
  is broken, not that the agent is weak.
- **held_out_season / held_out_match (6)** — no verified query covers
  them. These are the real measure of how well the semantic view
  generalises.
- **out_of_scope (3)** — toss, venue, ball-by-ball. The agent should say
  the data doesn't exist and not call the tool.

Ground truth came from the dev marts with 173 matches loaded (season to
28 June 2026). The `held_out_season` answers change as new scorecards land.

## Running

After every production deploy, the `agent-evals` job in
`.github/workflows/deploy.yml` creates the dataset if its version is new,
uploads the config and starts a run, without waiting for it. Read the
scores in Snowsight. See [docs/cicd.md](../../docs/cicd.md).

By hand: step through `run_eval.sql` with SnowSQL or the Snowflake CLI.

**Changing cases:** datasets are immutable. Edit the rows and bump `_V1`
→ `_V2` in both `eval_cases.sql` and `agent_evaluation_config.yaml`; the
next run creates the new dataset.

**Privileges** (running role): a Cortex database role (e.g.
`SNOWFLAKE.CORTEX_USER`), `EXECUTE TASK ON ACCOUNT`, `CREATE DATASET` and
`CREATE TABLE` on the schema, `USAGE` + `MONITOR` on the agent, `READ` on
the stage, and access to the semantic view.

**Reading scores:** agent orchestration is non-deterministic. Run the
dataset 2–3 times to find its normal range before treating a single drop
as a regression. `answer_correctness` is the most stable metric;
`tool_selection_accuracy` and `logical_consistency` move when the agent
takes a different path.
