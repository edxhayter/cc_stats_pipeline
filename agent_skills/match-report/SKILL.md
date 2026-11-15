---
name: match-report
description: Reports a single simulated match as an HTML dashboard plus a short written summary — result, innings scores, fall of wickets, partnerships and standout performances by Match Factor. Use when someone asks for a match report, recap, summary, scorecard or "what happened" in a specific match.
---

# Match report

## 1. Find the match

Identify the match from the teams and date (or competition). Teams may be
named either way round, so match on both home/away orientations. If more
than one match fits, list them and ask which one.

## 2. Gather (cricket_scorecards_analyst)

Run these as separate queries and keep each result's query ID:

1. **Result:** winner, margin (runs or wickets), result type, format,
   competition, date, man of the match.
2. **Innings totals:** per team and innings — runs, wickets lost, overs.
3. **Batting card:** every batter's runs, balls, fours, sixes, dismissal and
   per-match batting Match Factor, by team and innings.
4. **Bowling card:** every bowler's overs, maidens, runs, wickets, economy
   and per-match bowling Match Factor, by team and innings.
5. **Fall of wickets:** team score at each wicket, by innings.
6. **Partnerships:** runs per wicket, with both batters, by innings.

The data has no toss, venue, weather or ball-by-ball detail. Don't mention
or guess them.

## 3. Build the dashboard (code_execution)

Load each result inside the sandbox with
`SELECT * FROM TABLE(RESULT_SCAN('<query_id>'))` — don't re-query. Use
pandas and plotly and write one self-contained file,
`match_report_<team1>_v_<team2>_<date>.html` (plotly JS embedded, not from a
CDN), laid out top to bottom:

1. **Header band:** "<Winner> beat <loser> by <margin>", competition, format
   and date; man of the match with their figures.
2. **Scores strip:** one tile per innings — team, runs/wickets, overs.
3. **Fall of wickets:** line chart of score (y) against wicket number (x),
   one line per innings, so collapses and recoveries show as steep or flat
   stretches.
4. **Partnerships:** horizontal bars per innings, wicket 1 at the top,
   labelled with both batters; highlight the biggest stand in each innings.
5. **Standout performances:** two bar charts — top five batting and top five
   bowling per-match Match Factors across both sides, coloured by team, with
   a reference line at 1.0 (the match average).
6. **Scorecards:** batting and bowling tables per innings, sortable, Match
   Factor as the last column.

Footer: "2026 simulated season · Match Factor 1.0 = average performance in
this match".

## 4. Write the summary that goes with it

Under the dashboard link, three or four short paragraphs: how the match was
won, the turning point (a collapse, a big stand or a decisive spell), the
standout performers with their Match Factor (explained once: 1.0 is the
match average, 2.0 twice as effective), and anything the dashboard can't
show well. Every number must come from the data.
