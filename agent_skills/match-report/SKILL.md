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

Ask for everything below in as few analyst queries as possible — ideally
one or two — rather than one query per item.

- **Result:** winner, margin (runs or wickets), result type, format,
  competition, date, man of the match.
- **Innings totals:** per team and innings — runs, wickets lost, overs.
  Keep innings separate in multi-innings formats.
- **Top performers:** the three highest batting and three highest bowling
  per-match Match Factors across both sides, with their figures (runs off
  balls; wickets for runs off overs).
- **Partnerships:** the biggest stand in each innings, by wicket. The data
  doesn't record which batters made a stand, so don't name them.
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
- <player> (<team>): <figures>, Match Factor in this match <x.xx>

**Key partnerships:** <biggest stand per innings, by wicket, e.g. "155 for the second wicket">
```

Match Factor here is the single-match figure: label it "in this match"
and say once, briefly, that 1.0 is the average performance in this match,
so 2.0 means twice as effective. Every number must come from the data.

If the user asked for a dashboard, chart or other visual, also follow the
dashboard skill using the results gathered above.
