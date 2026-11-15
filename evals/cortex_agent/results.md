# Eval results log

One entry per experiment stage against `CRICKET_SCORECARDS_ANALYST_EVAL`
(frozen 235-match snapshot, dataset `CRICKET_AGENT_EVALSET_V1`, 21 cases).
Each stage is 3 runs, because agent orchestration is non-deterministic. Run
names carry the commit, so `git show <sha>` gives the exact agent spec,
semantic view and cases that were scored.

Scores are means across the 3 runs (0–1). Time and tokens are per question.

| Stage | Commit | Model | Answer correctness | Logical consistency | Tool selection | Avg s | Avg input tokens |
|---|---|---|---|---|---|---|---|
| 1. Baseline | `2da7f8d` | `auto` (Opus 5.5) | 0.974 | 0.974 | 0.873 | 7.7 | 59,900 |

## 1. Baseline — 2026-11-15

Runs: `baseline-2da7f8d-20261115-162512`, `-162558`, `-162610`.
Spec: response instructions only (no orchestration instructions), no
`models` block, semantic view with the pooled Match Factor metrics.

| Category | Answer correctness | Logical consistency | Tool selection |
|---|---|---|---|
| verified_query (9) | 0.95 | 0.96 | 1.00 |
| held_out_season (5) | 1.00 | 0.96 | 1.00 |
| held_out_match (2) | 1.00 | 1.00 | 1.00 |
| name_resolution (2) | 1.00 | 1.00 | 1.00 |
| out_of_scope (3) | 0.96 | 1.00 | 0.11 |

Every figure the agent gave was correct. Points were lost on:

- **Out-of-scope tool calls (0.11):** toss and venue questions queried the
  data in every run (ball-by-ball in 2 of 3) before saying the data doesn't
  have it. Answers were good; the calls are wasted time and credits.
- **Match Factor answers without an explanation:** batting 0.67 in all
  runs, bowling 0.67 in one. The value was right (2.20, 1.15); the expected
  answer also explains what the number means, and the agent didn't.
- **Venue (one run, 0.67):** "suggests it was played at a Hampshire
  ground" — a mild inference from the home team.
- **Logical consistency:** single-run dips on four cases; treated as noise.

Surname-only questions, including the ambiguous "Ali", scored 1.00 in
every run. Input tokens (~60k per question) dominate cost.
