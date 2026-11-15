---
name: player-profile
description: Profiles one player as an HTML dashboard of their simulated-season record (batting, bowling, fielding, Match Factor, form) with written real-world background from the web alongside, kept clearly separate. Use when someone asks to profile, summarise or "tell me about" a player, or how a player is doing overall.
---

# Player profile

## 1. Pin down the player

Names are stored as initial plus surname (for example J Porter). If the
question gives only a surname or a nickname, query the data for matching
players first. If more than one matches, list them with their team and ask
which one is meant before going further.

## 2. Simulated season (cricket_scorecards_analyst)

Run these for this player only and keep each result's query ID:

1. **Summary by format:** team, matches, runs, dismissals, average, strike
   rate, highest score, fifties, hundreds; wickets, runs conceded, average,
   economy, best figures, five-wicket hauls; catches, stumpings.
2. **Pooled Match Factor** for batting and bowling, for the season and by
   format.
3. **Match by match:** date, opponent, format, runs, balls, wickets, runs
   conceded, per-match batting and bowling Match Factor — every match, in
   date order.

Skip any discipline they didn't play rather than reporting zeros.
Stumpings mean they keep wicket.

## 3. Build the dashboard (code_execution)

Load each result with `SELECT * FROM TABLE(RESULT_SCAN('<query_id>'))` —
don't re-query. Use pandas and plotly and write one self-contained file,
`player_profile_<player>.html` (plotly JS embedded, not from a CDN):

1. **Header:** player name, team, role (batter, bowler, all-rounder,
   wicketkeeper — from what they did this season), formats played.
2. **KPI tiles:** matches; runs, average, strike rate; wickets, average,
   economy; catches/stumpings; pooled batting and bowling Match Factor,
   each tile coloured above or below 1.0.
3. **Form:** per-match Match Factor over the season (one line per
   discipline), reference line at 1.0, the last five matches highlighted.
4. **Output by match:** bars of runs (and wickets, on a second panel) per
   match, labelled by opponent.
5. **By format:** a table splitting the key figures by format.

Footer: "2026 simulated season · Match Factor 1.0 = match average; season
figures are pooled across matches".

The dashboard holds simulated-season data only.

## 4. Real-world background (web_search) — in the text, not the dashboard

Search for the real cricketer using the full surname plus the team from
step 2 (for example "Porter Essex cricketer"). Only treat a result as the
same player when the team, county or country lines up with the simulated
data; otherwise say you couldn't confirm the match and leave it out.

Take only context: full name, nationality, role, batting hand, bowling
style, teams, notable career history before 2026. Never take statistics for
2026 or later from the web.

## 5. Write the text that goes with it

- **Simulated season:** two or three sentences on what the dashboard shows
  — strengths, form trend, how their Match Factor compares with 1.0.
- **Background (real world, before the simulation):** two to four
  sentences from the web, with the source.

Never add pre-2026 real-world figures to simulated-season figures. If a
career total is asked for, give the simulated-season figure and note their
real-world record before the simulation is available separately.
