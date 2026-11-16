---
name: dashboard
description: Builds an HTML dashboard from data the analyst tool has already returned. Use ONLY when the user explicitly asks for a dashboard, chart, graph, plot, visual or visualisation — never as a default. Has layouts for match reports, player profiles and selection decisions, plus a general layout.
---

# Dashboard

Only build a dashboard when the user asked for something visual. If they
didn't, answer in text and Markdown tables instead and don't use this skill.

## How to build one (code_execution)

1. Get the data first with cricket_scorecards_analyst, as the matching skill
   (match-report, player-profile, selector) or the question requires, and
   keep each result's query ID.
2. In code_execution, load each result with
   `SELECT * FROM TABLE(RESULT_SCAN('<query_id>'))`. Don't re-query.
3. Use pandas and plotly. Write one self-contained HTML file with the plotly
   JS embedded (not loaded from a CDN), named after its subject, for example
   `match_report_hampshire_v_glamorgan_2026-05-01.html`.
4. Reply with the dashboard plus short accompanying text: what it shows, the
   two or three things worth noticing, and anything that doesn't suit a
   chart (real-world background, caveats, the recommendation's reasoning).

## Conventions for every dashboard

- **Charts, not cards.** Every panel below the header is a chart or a
  table that answers a question someone would ask about the subject. At
  most four headline numbers in the header band; no panels of notes or
  bullet points — commentary goes in the accompanying text.
- **Give context.** A figure on its own says little: show it against a
  benchmark (the format average for every qualifying player, the team's
  average, the opposition) or against time. One extra analyst query for
  the benchmark is worth it.
- **Title each chart with its finding**, not its axes: "Albert scores
  faster than any other Hampshire opener", not "Strike rate by player".
- Match Factor is the season pooled figure, labelled "season, pooled",
  except on a single-match dashboard, where it's labelled "in this match".
  Never show single-match Match Factors as a form line.
- Simulated-season data only. Real-world background from web_search goes in
  the accompanying text, never in the dashboard.
- Wherever Match Factor appears, draw a reference line at 1.0 (the match
  average) and colour values above and below it differently.
- Clean light theme, one accent colour per team, readable labels, no 3D or
  pie charts.
- Footer: "2026 simulated season · Match Factor 1.0 = match average; season
  figures are pooled across matches".

## Layout: match report

Data as in the match-report skill (result, innings totals, batting and
bowling cards with per-match Match Factor, fall of wickets, partnerships).

1. **Header band:** "<Winner> beat <loser> by <margin>", competition, format,
   date; man of the match with their figures.
2. **Scores strip:** one tile per innings — team, runs/wickets, overs.
3. **Fall of wickets:** score (y) against wicket number (x), one line per
   innings, so collapses and recoveries show as steep or flat stretches.
4. **Partnerships:** horizontal bars per innings, wicket 1 at the top,
   labelled with both batters; biggest stand per innings highlighted.
5. **Standout performances:** top five batting and top five bowling
   Match Factors in this match across both sides, coloured by team.
6. **Scorecards:** batting and bowling tables per innings, Match Factor last.

## Layout: player profile

Data as in the player-profile skill, plus each innings and bowling spell
this season and the format averages for qualifying players.

1. **Header:** player, team, role, formats played; up to four headline
   numbers.
2. **Against the field:** for each format they played, their batting
   average (x) against strike rate (y) — or bowling average against
   economy — as a highlighted point among every qualifying player in that
   format, with dashed lines at the format averages.
3. **Season in innings:** runs per innings as bars in date order (not-outs
   marked), coloured by format, with a line for their running average.
   Wickets per match the same way for bowlers.
4. **Pooled Match Factor through the season:** the running (cumulative)
   pooled figure after each match, built from the per-match ingredients,
   with a reference line at 1.0 — shows whether their season is building
   or fading without single-match noise.
5. **By format and level:** grouped bars of key figures for each format,
   international and county side by side.

## Layout: selection

Data as in the selector skill, plus the format averages for every
qualifying player (domestic and international) as the benchmark.

1. **Decision header:** team, format, role; one line naming the
   recommended pick and the incumbent, with the deciding figure for each.
2. **The field:** batting roles — average (x) against strike rate (y);
   bowling roles — average (x) against economy (y, lower is better). Every
   candidate labelled, sized by innings or matches, coloured by level
   (international or county), recommended and incumbent ringed; dashed
   lines at the format averages split the chart into quadrants, each
   labelled ("fast and reliable", "reliable but slow" and so on).
3. **Form:** small multiples, one per candidate, of runs per innings (or
   wickets per match) over the season in date order, last five
   highlighted, not-outs marked — the same y-axis for every candidate.
4. **County v international:** for candidates with both, a dumbbell chart
   of their average (and strike rate or economy) at each level.
5. **Season pooled Match Factor:** horizontal bars per candidate with a
   reference line at 1.0, each labelled with its sample size.
6. **Comparison table:** every candidate, key figures, last five scores or
   figures, sample-size and eligibility flags.

## Layout: anything else

For other visual requests (a leaderboard, a team's season, a comparison of
two players): a header stating the question, the one chart that answers it
best (ranked bars for leaderboards, lines over time for trends, grouped bars
for comparisons), and a supporting table.
