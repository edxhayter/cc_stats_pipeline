# Cortex Agent evals

Evaluates `CRICKET_SCORECARDS_ANALYST` with Snowflake's native
[Cortex Agent evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations)
(`EXECUTE_AI_EVALUATION`). Results show up in Snowsight under the agent's
**Evaluations** tab as well as via SQL.

| File | What it is |
|---|---|
| `eval_cases.sql` | Cases table + 31 cases with ground truth, then (re)creates dataset `CRICKET_AGENT_EVALSET` |
| `agent_evaluation_config.yaml` | Which agent and version (`LIVE`), which dataset, which metrics |
| `run_eval.sh` | Starts a run: rebuilds the dataset if the cases changed, uploads the config, names the run from git, optionally waits |
| `run_eval.sql` | Reads a run's status, per-case scores and errors |
| `../../terraform/envs/prod/agent_evals.tf` | Stage + file format the config is read from |

## What the evals test

The agent answers from live data that grows as scorecards land, so most
cases test **behaviour**, not exact figures. Following Snowflake's guidance
for changing data, their ground truth describes what a correct response
should and shouldn't contain. Whether the marts compute the right numbers is
the dbt tests' job; the verified queries pin down the semantic view's
answers to common questions.

- **out_of_scope (3)** — toss, venue, ball-by-ball: say the data doesn't
  have it, without calling any tool.
- **semantics (6)** — averages per dismissal, economy per over, totals
  across all of a player's teams, pooled Match Factor, minimum samples.
- **name_resolution (2)** — surname only: "Gubbins" (one match) and "Ali"
  (several; must not assume the real-world-famous M Ali).
- **sim_vs_web (2)** — simulated-season figures come from the data, never
  the web; "career" questions default to the simulated season.
- **web_context (2)** — real-world background and pre-simulation history via
  web search, labelled and kept separate.
- **skill (5)** — player-profile, match-report, selector and
  match-journalism (`agent_skills/`), in text. None expects
  `code_execution`, so an unasked-for dashboard costs tool selection. A
  second selector case for England checks that county players are
  considered; journalism must end by offering the newspaper page.
- **dashboard (2)** — explicit requests for a visual; the only cases that
  expect `code_execution`.
- **fixed_fact (9)** — exact figures that new matches can't change: the
  completed Hampshire v Glamorgan match of 1 May 2026, April 2026, and the
  completed England v New Zealand Test series. If
  one changes, dbt logic changed.

## Workflow

Terraform updates the agent directly, then the evals score it:

```sh
terraform -chdir=terraform/envs/prod apply
SNOWFLAKE_DATABASE=<db> evals/cortex_agent/run_eval.sh --label <what> --wait -- -c <connection>
```

The evals run against the live agent, so they report on a change rather
than gate it. A UAT environment, where the evals run before a change
reaches prod, is the intended next step. Until then, don't "Publish" the
agent in Snowsight: that commits a version, and users would then get it
instead of Terraform's updates.

Run the evals two or three times: agent orchestration is non-deterministic, so
find the normal range before treating one drop as a regression.
`answer_correctness` is the most stable metric; `tool_selection_accuracy`
and `logical_consistency` move when the agent takes a different path.
Record a change's before/after scores in its PR description.

`run_eval.sh` needs the Snowflake CLI and `jq`. It rebuilds the cases table
and dataset only when `eval_cases.sql` has changed (a hash of the file is
kept as the table comment), and names each run
`<label>-<git sha>[-dirty]-<UTC timestamp>`. Git is the history: `git show
<sha>:evals/cortex_agent/eval_cases.sql` gives the cases any run was scored
on. Arguments after `--` go to every `snow sql` call; `--wait` polls to
completion and prints the scores, seconds and input tokens per question.

To roll back, revert the change in git and apply again.

**Privileges** (running role): a Cortex database role (e.g.
`SNOWFLAKE.CORTEX_USER`), `EXECUTE TASK ON ACCOUNT`, `CREATE DATASET` and
`CREATE TABLE` on the schema, `USAGE` + `MONITOR` on the agent, `READ` on
the stage, and access to the semantic view.
