---
name: player-profile
description: Builds a profile of one player — their simulated-season record (batting, bowling, fielding, Match Factor, form) plus real-world background from the web, kept clearly separate. Use when someone asks to profile, summarise or "tell me about" a player, or how a player is doing overall.
---

# Player profile

## 1. Pin down the player

Names are stored as initial plus surname (for example J Porter). If the
question gives only a surname or a nickname, query the data for matching
players first. If more than one matches, list them with their team and ask
which one is meant before going further.

## 2. Simulated season (cricket_scorecards_analyst only)

Pull, for this player only:

- Team(s) and formats played, matches played.
- Batting: runs, dismissals, average, strike rate, highest score, fifties
  and hundreds — if they batted in the top six, the pooled batting Match
  Factor for the season.
- Bowling: wickets, runs conceded, average, economy, best figures,
  five-wicket hauls, pooled bowling Match Factor.
- Fielding: catches and stumpings (stumpings mean they keep wicket).
- Form: their last five matches with the per-match Match Factor, so a
  reader can see whether they're trending up or down.

Skip any discipline they didn't play rather than reporting zeros.

## 3. Real-world background (web_search)

Search for the real cricketer, using the full surname plus the team from
step 2 (for example "Porter Essex cricketer"). Only treat a web result as
the same player when the team, county or country lines up with the
simulated data; if it doesn't, say you couldn't confirm the match and leave
the background out.

Take only context: full name, nationality, role, batting hand, bowling
style, teams, and notable career history before 2026. Never take statistics
for 2026 or later from the web — the simulated season replaces them.

## 4. Present it

```
## <Player> — <team>, <role>

**2026 simulated season**
<key figures as a short table: matches, runs/avg/SR, wickets/avg/econ,
catches/stumpings, pooled Match Factor(s)>

**Form** — last five matches with per-match Match Factor, one line each.

**Background (real world, before the simulation)**
<2–4 sentences of web context, with the source>
```

Keep the two sections visibly separate and never add pre-2026 real-world
figures to the simulated-season figures. If a career total is asked for,
give the simulated-season figure and note that their pre-2026 real-world
record is available separately.

When reporting a Match Factor, say what it means: 1.0 is the match average,
higher is better, and a season figure is pooled across all their matches.
