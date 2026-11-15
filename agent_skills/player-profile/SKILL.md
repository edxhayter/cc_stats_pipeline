---
name: player-profile
description: Profiles one player in text — their simulated-season record (batting, bowling, fielding, Match Factor, form) plus real-world background from the web, kept clearly separate. Use when someone asks to profile, summarise or "tell me about" a player, or how a player is doing overall.
---

# Player profile

## 1. Pin down the player

Names are stored as initial plus surname (for example J Porter). If the
question gives only a surname or a nickname, query the data for matching
players first. If more than one matches, list them with their team and ask
which one is meant before going further.

## 2. Simulated season (cricket_scorecards_analyst)

Ask for everything below in as few analyst queries as possible — ideally
one or two — rather than one query per item.

For this player only:

- Team(s), formats played, matches played. Season totals cover all their
  teams (county and country); split by team only as context.
- Batting: runs, dismissals, average, strike rate, highest score, fifties
  and hundreds; pooled batting Match Factor if they batted in the top six.
- Bowling: wickets, runs conceded, average, economy, best figures,
  five-wicket hauls, pooled bowling Match Factor.
- Fielding: catches and stumpings (stumpings mean they keep wicket).
- Form: their last five matches with the per-match Match Factor.

Skip any discipline they didn't play rather than reporting zeros.

## 3. Real-world background (web_search)

Search for the real cricketer using the full surname plus the team from
step 2 (for example "Porter Essex cricketer"). Only treat a result as the
same player when the team, county or country lines up with the simulated
data; otherwise say you couldn't confirm the match and leave it out.

Take only context: full name, nationality, role, batting hand, bowling
style, teams, notable career history before 2026. Never take statistics for
2026 or later from the web.

## 4. Write it

```
## <Player> — <team>, <role>

**2026 simulated season**
<key figures as a short table: matches, runs/avg/SR, wickets/avg/econ,
catches/stumpings, pooled Match Factor(s)>

**Form** — last five matches with per-match Match Factor, one line each.

**Background (real world, before the simulation)**
<two to four sentences from the web, with the source>
```

Keep the two sections visibly separate and never add pre-2026 real-world
figures to simulated-season figures. If a career total is asked for, give
the simulated-season figure and note their real-world record before the
simulation is available separately. When reporting a Match Factor, say what
it means: 1.0 is the match average, higher is better, and a season figure
is pooled across their matches.

If the user asked for a dashboard, chart or other visual, also follow the
dashboard skill using the results gathered above.
