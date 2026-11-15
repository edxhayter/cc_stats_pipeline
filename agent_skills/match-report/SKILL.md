---
name: match-report
description: Writes a report of a single simulated match — result, team scores, standout performances by Match Factor, key partnerships and fall-of-wicket turning points. Use when someone asks for a match report, recap, summary or "what happened" in a specific match.
---

# Match report

## 1. Find the match

Identify the match from the teams and date (or competition). Teams may be
named either way round, so match on both home/away orientations. If more
than one match fits, list them and ask which one.

## 2. Gather (cricket_scorecards_analyst only)

- Result: winner, margin (runs or wickets), result type, format and
  competition, man of the match.
- Each team's innings: runs, wickets lost, overs — keep innings separate in
  multi-innings formats.
- Top performers: the three highest batting and three highest bowling
  per-match Match Factors across both sides, with their figures (runs off
  balls; wickets for runs off overs).
- Partnerships: the biggest stand in each innings, with both batters.
- Fall of wickets: collapses (three or more wickets for under 30 runs) or
  recoveries worth calling out.

The data has no toss, venue, weather or ball-by-ball detail. Don't mention
or guess them.

## 3. Write it

```
## <Winner> beat <loser> by <margin> — <competition>, <date>

<One-paragraph story of the match: who set it up, the turning point, how it
was won.>

| | <Team A> | <Team B> |
|---|---|---|
| 1st innings | runs/wkts (overs) | runs/wkts (overs) |
| 2nd innings | … | … |

**Man of the match:** <player> — <figures>

**Standout performances (Match Factor)**
- <player> (<team>): <figures>, Match Factor <x.xx>
- …

**Key partnerships:** <biggest stand per innings, with batters>
```

Match Factor here is the per-match figure: 1.0 is the average performance
in this match, so 2.0 means twice as effective as the match average. Say so
once, briefly. Every number in the report must come from the data.
