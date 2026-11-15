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
   per-match Match Factors across both sides, coloured by team.
6. **Scorecards:** batting and bowling tables per innings, Match Factor last.

## Layout: player profile

Data as in the player-profile skill (summary by format, pooled Match
Factor, match-by-match record).

1. **Header:** player, team, role, formats played.
2. **KPI tiles:** matches; runs, average, strike rate; wickets, average,
   economy; catches/stumpings; pooled batting and bowling Match Factor.
3. **Form:** per-match Match Factor over the season, one line per
   discipline, last five matches highlighted.
4. **Output by match:** runs and wickets per match, labelled by opponent.
5. **By format:** key figures split by format.

## Layout: selection

Data as in the selector skill (candidates' season figures in the format,
last-five-match form, balance check).

1. **Decision header:** team, format, role; three cards — **Recommended**,
   **Incumbent**, **Other options** — with headline figures.
2. **Comparison chart:** batting roles — average (x) against strike rate
   (y); bowling roles — average (x) against economy (y, lower is better).
   One labelled point per candidate, sized by matches, recommended and
   incumbent highlighted.
3. **Form strip:** each candidate's last five per-match Match Factors.
4. **Comparison table:** every candidate, key figures, pooled Match Factor,
   sample-size flag.
5. **Balance panel:** what the pick does to keeper, bowling options and
   batting depth.

## Layout: anything else

For other visual requests (a leaderboard, a team's season, a comparison of
two players): a header stating the question, the one chart that answers it
best (ranked bars for leaderboards, lines over time for trends, grouped bars
for comparisons), and a supporting table.
