---
name: match-report
description: Reports a single simulated match in text — result, innings scores, standout performances by Match Factor, key partnerships and turning points. Use when someone asks for a match report, recap, summary, scorecard or "what happened" in a specific match.
---

# Match report

## 1. Find the match

Identify the match from the teams and date (or competition). Teams may be
named either way round, so match on both home/away orientations. If more
than one match fits, list them and ask which one.

## 2. Gather (cricket_scorecards_analyst)

- **Result:** winner, margin (runs or wickets), result type, format,
  competition, date, man of the match.
- **Innings totals:** per team and innings — runs, wickets lost, overs.
  Keep innings separate in multi-innings formats.
- **Top performers:** the three highest batting and three highest bowling
  per-match Match Factors across both sides, with their figures (runs off
  balls; wickets for runs off overs).
- **Partnerships:** the biggest stand in each innings, with both batters.
- **Fall of wickets:** collapses (three or more wickets for under 30 runs)
  or recoveries worth calling out.

The data has no toss, venue, weather or ball-by-ball detail. Don't mention
or guess them.

## 3. Write it

```
## <Winner> beat <loser> by <margin> — <competition>, <date>

<One paragraph on how the match was won: who set it up, the turning point.>

| | <Team A> | <Team B> |
|---|---|---|
| 1st innings | runs/wkts (overs) | runs/wkts (overs) |
| 2nd innings | … | … |

**Man of the match:** <player> — <figures>

**Standout performances (Match Factor)**
- <player> (<team>): <figures>, Match Factor <x.xx>

**Key partnerships:** <biggest stand per innings, with batters>
```

Match Factor here is the per-match figure: 1.0 is the average performance
in this match, so 2.0 means twice as effective. Say so once, briefly. Every
number must come from the data.

If the user asked for a dashboard, chart or other visual, also follow the
dashboard skill using the results gathered above.
