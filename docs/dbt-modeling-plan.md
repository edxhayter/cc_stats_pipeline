# dbt Modeling Plan — Cricket Scorecard Transform

Status: design agreed, staging layer not yet built. This doc reflects
decisions made collaboratively before writing any models — update it as
the design evolves rather than letting it drift from what's actually built.

## Source

`CRICKET_SCORECARDS_RAW.SCORECARD_LINES` — one row per raw text line from a
scorecard file, plus `source_file_name`, `source_file_row_number`, `loaded_at`.
Each file is one match. Format is consistent across match types, with two
known structural variants:

- **Limited overs (T20, ODI):** 2 innings blocks per file (one per team).
  Bowling column header is `O  D  R  W  Econ` — **D is Dots, not Maidens.**
- **First Class / Test:** 4 innings blocks per file (each team bats twice)
  — **except an innings-victory match, which only has 3** (the winning
  team's single innings outscored the opponent's two completed innings
  combined, so they never bat again — confirmed in 2 of 173 real files).
  Bowling column header is `O  M  R  W  Econ` (Maidens).

Competition/date line has five known format variants (discovered by
running against all 173 real files, not assumed up front):
`TEST`, `ODI`, `T20` (domestic "20 Over Trophy"), `T20I` (international
"20 Over International" — same bracketed `"{ordinal} {type} (of N)"`
structure as TEST/ODI, easy to miss since it reads like domestic T20 at
a glance), `FC_LEAGUE`.

Other format notes:
- Block boundaries are marked by lines of `*` characters.
- Innings headers follow `"{Team} - {1st|2nd} Innings"`.
- Batting rows for players who didn't come in to bat have a name only, no
  stats — these are meaningful (squad visibility) and must be preserved,
  not dropped.
- Fall-of-wickets wraps onto a second line once more than ~5 wickets have
  fallen, and won't reach 10 entries if the innings didn't end all-out.
- Match results include an **innings victory** phrasing — "Sussex won by
  an innings and 83 runs" — distinct from a plain runs margin. A naive
  parse of "won by (\d+)" fails to match "an" and would silently produce
  a null margin while still misclassifying it as a RUNS result; confirmed
  in 2 of 173 files. `result_margin_type` has a dedicated `INNINGS` value
  for this (see Marts section).

## Layering

**Staging — strictly 1:1 grain with the source (one row per raw line).**
No reshaping happens here, only annotation. This was corrected from an
earlier draft that had staging models doing grain changes (one row per
batter/bowler) — that's intermediate-layer work, not staging.

- `stg_scorecard_lines` — light rename/cast pass-through of the source
- `stg_blocks` — adds `block_id` / `block_type` per line via gaps-and-islands
  (running-sum of marker-line count); `block_type` ∈ `match_header`,
  `batting`, `bowling`, `fall_of_wickets`, `result`
- `stg_row_classification` — adds `row_type` per line within a block
  (data row / divider / extras / total / header)

**Intermediate — this is where parsing/reshaping actually happens; grain
changes from "one row per line" to a structured row per entity.**

- `int_match_header` — one row per match: teams, date, competition name + variant
- `int_result` — one row per match: winning team, margin, man of the match
- `int_batting_rows` — one row per batter × innings × match (includes
  did-not-bat rows)
- `int_bowling_rows` — one row per bowler × innings × match
- `int_fow_rows` — one row per wicket × innings × match (handles the line-wrap)
- `int_innings_totals` — one row per team-innings × match: total runs,
  wickets lost, overs faced, extras (parsed from the `Extras:`/`TOTAL:`
  lines) — needed for the contribution-to-team-% measures below, and
  currently the only place those totals exist independent of summing
  `int_batting_rows` per innings (cheaper and avoids recomputation)
- `int_partnerships` — one row per partnership × team-innings × match.
  Partnership runs come from consecutive fall-of-wickets deltas (already
  planned), but the two batters involved can also be derived deterministically:
  simulate the innings in batting-position order — two batters open, and
  each time a wicket falls, the dismissed batter (identified by matching
  the dismissal to whichever of the current pair is out) is replaced by
  the next batter in `batting_position` order. This gives named partnerships
  ("1st wicket: Gubbins & Orr, 66") rather than just a runs figure.
  **Confirmed risk, not just hypothetical:** `int_batting_rows` found
  retired-hurt genuinely occurs — Sri Lanka's K Mendis is listed twice in
  the same innings (both innings, in fact) in
  "25 Jun 2026-WI v SL (1st TST).txt" (6 of 5544 batting rows have
  `dismissal_type = RETIRED_HURT` overall). The strict batting-position
  simulation described above will need explicit handling for this exact
  case when `int_partnerships` is built — a retired batter returning
  breaks the "next batter in order" assumption. This also means
  `fact_batting`'s grain (see Marts section) isn't strictly one row per
  player per team-innings — `batting_position` disambiguates the two
  stints.
- `int_fielding_dismissals` — one row per catch/stumping event, parsed out
  of `dismissal_detail` (`"c Ingram b Kellaway"` → fielder `Ingram`;
  `"st Rizwan b Khan"` → keeper `Rizwan`). Run-outs in this source format
  don't credit a fielder, so this only ever produces `CAUGHT`/`STUMPED` rows

All reshaped innings-grain models carry both `team_innings_number` (1/2,
relative to that team) and `match_innings_sequence` (1–4, chronological
order across the whole match) — the latter is just the ordinal position of
each `batting`/`bowling` block pair among all such blocks in the match, so
it falls out of the same block segmentation `stg_blocks` already does; no
separate derivation logic needed.

**Marts — dimensional model + enrichment for BI and Cortex Analyst.**

Explicit column-level spec below, so the semantic layer (built later,
directly on top of these) can be equally explicit about what it exposes —
each measure is marked with how it's meant to be aggregated, since some
(strike rate, economy, Match Factor) are ratios that must not simply be
summed across rows.

### `dim_team`

| Column | Type | Notes |
|---|---|---|
| `team_id` | surrogate key | |
| `team_name` | string | natural key |

### `dim_player`

| Column | Type | Notes |
|---|---|---|
| `player_id` | surrogate key | |
| `player_name` | string | natural key — open limitation, see below |

### `dim_match`

`match_format` lives flat on `dim_match` (not snowflaked into its own
dimension table) — every match has exactly one format, so there's no
reuse benefit to normalizing it out, only an extra join for every query.

| Column | Type | Notes |
|---|---|---|
| `match_id` | surrogate key | |
| `source_file_name` | string | natural key — guaranteed unique, avoids the collision risk a parsed date+teams+competition key would carry on a same-day doubleheader |
| `match_date` | date | |
| `home_team_id` | FK → `dim_team` | the team listed first in the source file name/header — by convention, the home team |
| `away_team_id` | FK → `dim_team` | |
| `competition_name` | string | e.g. "English FC League", "20 Over Trophy", "One Day International", "Test Match", "20 Over International" |
| `competition_variant` | string | e.g. "D1", "Mid & West", "2nd Test Match (of 2)" |
| `match_format` | string enum | `TEST` / `ODI` / `T20` / `T20I` / `FC_LEAGUE` — extracted directly from the competition line, not just derived from innings-block count. `T20I` is a real discovery (see Source section), not part of the original 4-value design |
| `innings_per_team` | int | `1` (limited overs) or `2` (Test/FC) — kept as a simple derived flag alongside `match_format` for downstream logic that just needs the count. Note an innings-victory FC match still has `innings_per_team = 2` here (that's the format's normal rule) even though one team's actual innings count for that specific match was only 1 — this column describes the format, not the realized per-match count |
| `winning_team_id` | FK → `dim_team`, nullable | null if drawn/no result |
| `result_type` | string enum | `WIN` / `DRAW` / `TIE` / `NO_RESULT` — `DRAW` confirmed present in real data (9 of 173 files); `TIE`/`NO_RESULT` remain unconfirmed |
| `result_margin_type` | string enum, nullable | `RUNS` / `WICKETS` / `INNINGS` — `INNINGS` is a real discovery ("won by an innings and N runs", see Source section), not part of the original design |
| `result_margin_value` | number, nullable | |
| `man_of_the_match_id` | FK → `dim_player`, nullable | |

### `fact_batting`

Grain: batting stint × team-innings × match — **not strictly player ×
team-innings × match**. A retired-hurt batter who returns is listed twice
in the same innings (confirmed in real data, see `int_batting_rows`
above); `batting_position` is the true disambiguator, not `player_id`
alone.

| Column | Type | Role | Notes |
|---|---|---|---|
| `match_id` | FK → `dim_match` | dimension | |
| `player_id` | FK → `dim_player` | dimension | |
| `team_id` | FK → `dim_team` | dimension | batting team |
| `opposition_team_id` | FK → `dim_team` | dimension | denormalized convenience |
| `team_innings_number` | int (1 or 2) | dimension | which innings **for that team** |
| `match_innings_sequence` | int (1–4) | dimension | overall chronological order of the innings **within the match** — team A's 1st = 1, team B's 1st = 2, team A's 2nd = 3, team B's 2nd = 4. Distinct from `team_innings_number`; useful for follow-on/declaration-order analysis that per-team numbering alone can't answer |
| `batting_position` | int | dimension | order in the lineup |
| `dismissal_type` | string enum | dimension | `CAUGHT` / `BOWLED` / `LBW` / `RUN_OUT` / `STUMPED` / `NOT_OUT` / `DID_NOT_BAT` / `RETIRED_HURT` — same vocabulary as `fact_fielding.dismissal_type` for the overlapping values, since a caught dismissal is the same event in both places. `RETIRED_HURT` is a real discovery (see Source section) |
| `dismissal_detail` | string, nullable | dimension | raw dismissal text (bowler/fielder) |
| `did_not_bat` | boolean | dimension | |
| `runs` | number | measure — **summable** | |
| `balls_faced` | number | measure — **summable** | |
| `fours` | number | measure — **summable** | |
| `sixes` | number | measure — **summable** | |
| `strike_rate` | number | measure — **non-additive** | `runs / balls_faced × 100`; must be recomputed from summed runs/balls at query time, never summed/averaged directly across rows |
| `pct_of_team_innings_runs` | number | measure — **non-additive** | `runs / int_innings_totals.total_runs` for that team-innings; recompute at query time from summed components, don't average the column |
| `batting_match_factor` | number, nullable | measure — **avg or sum over a period** (see Match Factor section) | |

### `fact_bowling`

Grain: bowler × team-innings × match.

| Column | Type | Role | Notes |
|---|---|---|---|
| `match_id` | FK → `dim_match` | dimension | |
| `player_id` | FK → `dim_player` | dimension | bowler |
| `team_id` | FK → `dim_team` | dimension | bowling team |
| `opposition_team_id` | FK → `dim_team` | dimension | batting team |
| `team_innings_number` | int (1 or 2) | dimension | |
| `match_innings_sequence` | int (1–4) | dimension | see `fact_batting` note above |
| `overs` | number | measure — **not simply summable** | stored as e.g. `7.4` meaning 7 overs + 4 balls, not a decimal fraction — needs conversion to total balls before any arithmetic |
| `maidens` | number, nullable | measure — **summable** | FC/Test/ODI only |
| `dots_bowled` | number, nullable | measure — **summable** | T20 only — never blended with `maidens`, different stat |
| `runs_conceded` | number | measure — **summable** | |
| `wickets` | number | measure — **summable** | |
| `economy` | number | measure — **non-additive** | `runs_conceded / overs_as_decimal`; recompute from summed components, don't average the column directly |
| `pct_of_team_innings_wickets` | number | measure — **non-additive** | `wickets / int_innings_totals.wickets_lost` for the opposition's innings; recompute at query time, don't average the column |
| `bowling_match_factor` | number, nullable | measure — **avg or sum over a period** | NULL for wicketless matches, see Match Factor section |

### `fact_fow`

Grain: wicket × team-innings × match.

| Column | Type | Role |
|---|---|---|
| `match_id` | FK → `dim_match` | dimension |
| `team_id` | FK → `dim_team` | dimension |
| `team_innings_number` | int (1 or 2) | dimension |
| `match_innings_sequence` | int (1–4) | dimension |
| `wicket_number` | int (1–10) | dimension |
| `cumulative_score` | number | measure — non-additive across wickets (it's already cumulative); useful for partnership derivation |

### `fact_partnership`

Grain: partnership × team-innings × match. Built from `int_partnerships`
(see intermediate layer) — named partnerships, not just a runs figure.

| Column | Type | Role | Notes |
|---|---|---|---|
| `match_id` | FK → `dim_match` | dimension | |
| `team_id` | FK → `dim_team` | dimension | |
| `team_innings_number` | int (1 or 2) | dimension | |
| `match_innings_sequence` | int (1–4) | dimension | |
| `partnership_number` | int (1–10) | dimension | 1 = opening partnership |
| `batter_1_id` / `batter_2_id` | FK → `dim_player` | dimension | the two batters at the crease for this partnership |
| `how_ended` | string enum, nullable | dimension | dismissal type that ended it; null if the innings ended with this partnership unbroken (all out never reached — e.g. declaration, chase completed, overs ran out) |
| `partnership_runs` | number | measure — **summable** | `cumulative_score` at wicket *n* − at wicket *n-1* (or team total, for an unbroken final partnership) |

### `fact_fielding`

Grain: one row per catch/stumping dismissal event. Built from
`int_fielding_dismissals`. Run-outs aren't included — this source format
doesn't credit a fielder for them.

| Column | Type | Role | Notes |
|---|---|---|---|
| `match_id` | FK → `dim_match` | dimension | |
| `team_id` | FK → `dim_team` | dimension | fielding team (opposition of the batting team) |
| `team_innings_number` | int (1 or 2) | dimension | |
| `match_innings_sequence` | int (1–4) | dimension | |
| `fielder_id` | FK → `dim_player` | dimension | the credited catcher/stumper |
| `bowler_id` | FK → `dim_player` | dimension | bowler who took the wicket |
| `batter_id` | FK → `dim_player` | dimension | batter dismissed |
| `dismissal_type` | string enum | dimension | `CAUGHT` or `STUMPED` only |

Row count itself is the measure here (`COUNT(*)` filtered by
`dismissal_type` gives catches or stumpings) — no separate numeric column needed.

Enrichment marts still at the design-bullet stage (not yet column-specified,
lower priority than the above):
- **Player/team match-summary marts** — one row per player per match
  (batting + bowling + fielding combined via the facts above) and one row
  per team per match — including a `batted_first` boolean (whichever team's
  innings has the lower `match_innings_sequence`) to support the contextual
  win/loss and bat-first/chase splits agreed above
- **Notable performances / milestones** — flags for centuries, 5-wicket
  hauls, match-winning knocks
- **Season/competition rolling aggregates** — pre-aggregated player/team
  stats for "top run scorer this season"-style questions, plus consistency/
  volatility (stdev of scores over a period) and an all-rounder composite
  index (batting + bowling contribution combined)

**Known gaps, not solvable from this source regardless of modeling effort:**
no toss data, no venue, no ball-by-ball or phase splits (powerplay/death
overs) — none of it exists in the scorecard text.

## Advanced metrics: Match Factor

Computed **at match grain** (not a career aggregate) — this is required
because the calculation excludes the player from their own peer group,
which can only be expressed cleanly before rolling up across matches.
Rollup over any period (season, competition, career) happens later, in
the semantic layer (see below), not by pre-baking a rollup grain into the mart.

**Batting Match Factor** (per player, per match):
```
  (player's runs in this match ÷ player's dismissals in this match)
  ÷
  (sum of other top-6 batters' runs in this match, excluding the player
     ÷ sum of their dismissals, excluding the player)
```
- Peer group = other top-6 batters in the *same match* (naturally scoped
  to the same format, since a match is one format).
- Player excluded from the peer-group denominator to avoid circularity.
- Edge case: player not out in every innings they played (zero dismissals)
  → use total runs as the batting-average stand-in for that match.

**Bowling Match Factor** (per player, per match):
```
  (sum of other bowlers' runs conceded in this match, excluding the player
     ÷ sum of their wickets, excluding the player)
  ÷
  (player's runs conceded in this match ÷ player's wickets in this match)
```
- Higher = better for both metrics (ratio orientation is inverted between
  batting and bowling specifically so "higher is better" holds for both).
- Edge case: player took zero wickets in the match → **NULL** the factor
  for that match (undefined, not zero) — this also means it's correctly
  excluded when later averaged/summed, rather than dragging the rollup
  down with an artificial zero.
- Discipline segmentation (pace vs. spin peer groups) — **deferred for v1**.
  Not present in source data; would need a maintained seed CSV mapping
  player → bowling style. Revisit if the undifferentiated peer group proves
  too noisy.

**Where this lives:** computed once at match grain in the marts layer,
then exposed as a base measure in the Snowflake Semantic View so Cortex
Analyst (or any BI consumer) can aggregate it over whatever period a
question implies — season, competition, career — without that grain
being fixed in the mart itself.

## Conventions

- **Materialization:** staging and intermediate models as `view`s (cheap,
  always reflect the latest raw data, no storage cost for what's really
  just annotation/reshaping logic); marts as `table`s (queried repeatedly
  by BI/Cortex Analyst, worth materializing physically). Standard dbt
  layering convention, set via `dbt_project.yml` rather than per-model
  config where possible.
- **Surrogate keys:** generated via a hash of each model's natural key
  (e.g. `dbt_utils.generate_surrogate_key`) rather than a sequence, so
  keys are stable across full-refreshes and don't depend on load order.

## Testing strategy

Not an afterthought — tests are what make the gaps-and-islands parsing
approach trustworthy rather than "looks right on three sample files":

- **Row-count reconciliation:** a singular test asserting `stg_blocks`
  preserves the exact row count of `stg_scorecard_lines` per file (staging
  must never drop or duplicate raw lines, only annotate them)
- **Standard dbt tests** on every mart: `unique`/`not_null` on surrogate
  and natural keys, `relationships` tests for every FK → dimension
- **Cross-validation test:** `fact_fielding`'s catch/stumping counts per
  bowler, summed per match, should reconcile against `fact_bowling.wickets`
  for that same bowler (every caught/stumped wicket must trace back to a
  credited bowler) — this is exactly the kind of check that would catch
  the retired-hurt/partnership-pairing risk noted above, if it exists in
  a larger sample
- **Format-scoping test on Match Factor:** peer group for a given match
  should only ever include batters/bowlers *from that same match* — a
  test asserting no cross-match leakage would catch a join mistake early

## Open items / known limitations

- `dim_player` natural key is player name alone (e.g. "N Gubbins") — no
  guarantee of uniqueness across teams/countries if two different real
  players ever share an abbreviated name. Flagged, not yet solved.
- Bowling Match Factor's pace/spin discipline split is deferred (see above).
- Season/competition rollup grain for Match Factor (and other rolling
  aggregates) is intentionally left to the semantic layer, not fixed here.
- `int_partnerships`' batting-order simulation will need explicit
  retired-hurt handling — confirmed to occur (1 of 173 files), not just a
  hypothetical risk (see above). Not yet built.

## Build order (this doc's scope)

Tests (see Testing strategy above) get written alongside each step, not
bolted on at the end — e.g. the row-count reconciliation test belongs to
step 1, `relationships` tests belong to step 4 as each mart is built.

1. ~~`sources.yml` + `stg_scorecard_lines` + `stg_blocks` + `stg_row_classification`~~ ✅
2. ~~`int_match_header` + `int_result` + `int_innings_totals`~~ ✅
3. ~~`int_batting_rows` + `int_bowling_rows` + `int_fow_rows`~~ ✅
4. ~~Core marts: `dim_team`, `dim_player`, `dim_match`, `fact_batting`,
   `fact_bowling`, `fact_fow` (including contribution-to-team-% measures)~~ ✅
5. Match Factor columns on `fact_batting` / `fact_bowling`
6. `int_partnerships` + `int_fielding_dismissals` → `fact_partnership` + `fact_fielding`
7. Player/team match-summary marts, milestones, rolling aggregates
   (consistency/volatility, all-rounder composite)
8. ~~Semantic views for Cortex Analyst~~ ✅ (first pass — see below; done
   out of order, ahead of steps 5-7, and will need extending once those
   land)

## Semantic layer

Built as a dbt model (`models/semantic/sv_cricket_scorecards.sql`) using
the `Snowflake-Labs/dbt_semantic_view` package — `materialized='semantic_view'`
executes native `CREATE SEMANTIC VIEW` DDL, with the model body written
directly in that syntax (`TABLES`/`RELATIONSHIPS`/`FACTS`/`DIMENSIONS`/`METRICS`),
referencing the existing marts via `ref()` for normal dbt dependency tracking.

**Deliberately not defined in Terraform.** The semantic view is data
modeling — it's built directly on the mart tables' column structure via
`ref()`, so it belongs in the same tool that owns that structure (dbt).
Defining it in Terraform would mean hardcoding mart column names in a
second place that has no mechanism to stay in sync when a mart changes.
This matches the project's existing split: Terraform owns infrastructure
dbt doesn't/can't manage (storage integration, warehouse reference,
tasks); dbt owns everything about the shape of the data, semantic view
included. What *does* belong in Terraform: the Snowflake role + grants
controlling who/what can query the semantic view — that's access-control
infrastructure, already listed under "Snowflake — planned, not yet built"
in the Terraform resources section above. Not yet built.

**Clause order matters and isn't obvious from examples alone**: the formal
grammar is `TABLES → RELATIONSHIPS → FACTS → DIMENSIONS → METRICS` — FACTS
before DIMENSIONS, which is easy to get backwards. Also: every logical
table needs an explicit `PRIMARY KEY (...)` declared in `TABLES` before it
can be the referenced side of any `RELATIONSHIPS` entry — omitting it
fails with a semantic (not syntax) error at creation time.

**Role-playing dimensions**: `dim_team` and `dim_player` are each
referenced multiple times under different aliases (`home_teams`,
`away_teams`, `winning_teams`, `batting_teams`, `bowling_teams`; `batters`,
`bowlers`, `motm_players`) since the same physical dimension plays
different roles depending on which relationship is in view. Confirmed
supported directly by Snowflake's own syntax.

**Validated**, not just compiled: queried `SEMANTIC_VIEW(...)` directly
and cross-checked against numbers manually verified from the Ham v Glm
sample file at the very start of this build — N Gubbins: 149 runs, 2
innings, average 74.5, exact match. Bowling metrics spot-checked too.

**Known simplification carried over from the marts**: `fact_bowling.overs`
is summed as a naive decimal in the `total_overs_naive`/`economy_rate`
metrics (7.4 means 7 overs + 4 balls, not 7.4 decimal overs) — an
approximation, not exact. Refine later by converting to total balls
bowled before aggregating.

**Verified queries**: `AI_VERIFIED_QUERIES` is a genuinely recent
`CREATE SEMANTIC VIEW` clause (postdated the syntax reference fetched
earlier in this build) — curated `QUESTION`/`SQL` pairs that improve
Cortex Analyst's accuracy on the question shapes users actually ask.
Clause sits after `METRICS`. The `SQL` in each entry is plain SQL against
the physical mart tables (what Cortex Analyst itself generates under the
hood), not the `SEMANTIC_VIEW(...)` wrapper syntax used for manual
testing — the two are different things and shouldn't be confused. Three
seeded so far (batting average, bowler wickets/economy, match result +
MOTM), each independently validated by running its embedded SQL directly
and confirming it matches numbers already verified elsewhere in this doc.
More should be added as real usage surfaces the question shapes people
actually ask.

A small diagnostic macro (`macros/run_sql.sql`) was added alongside this
— `dbt show` always appends a `LIMIT` clause, which breaks non-`SELECT`
statements like `DESCRIBE SEMANTIC VIEW`. `dbt run-operation run_sql
--args '{sql: "..."}'` is the workaround, worth knowing about for any
future non-`SELECT` diagnostic query.

## Cortex Agent (separate from the semantic view — not yet built)

The agent is a distinct Snowflake object from the semantic view:
`CREATE AGENT` bundles a model choice, tool references (including the
semantic view), orchestration instructions, and sample questions into one
schema-level object that Snowsight/the REST API actually talks to.

**This one *does* belong in Terraform**, unlike the semantic view itself
— confirmed via `snowflake_cortex_agent`, a real resource in the
`snowflakedb/snowflake` Terraform provider (currently a **preview**
feature, needs `preview_features_enabled = true` set on the provider).
The reasoning that kept the semantic view out of Terraform doesn't apply
here: the agent doesn't need to know mart column structure, it just
references the semantic view by name — a loose, infrastructure-shaped
coupling, not a data-modeling one. Its `specification` argument is an
opaque YAML blob (model, tools, tool_resources, instructions, sample
questions) that Terraform passes through rather than typing individual
fields for.

Not yet built — needs design input (model choice, agent persona/
instructions, which sample questions to surface) before writing the
Terraform resource.
