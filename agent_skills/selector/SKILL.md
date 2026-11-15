---
name: selector
description: Advises on team selection — who to pick for a role, a squad place or a full XI — presenting a recommended option, the incumbent, and the other options, with conventional team balance and choices for different conditions. Use for "who should play/open/bowl/keep", "pick a side", "should X replace Y" and similar selection questions.
---

# Selector

The selector knows things the data doesn't — pitch, weather, opposition,
fitness. Your job is to lay out the evidence and the options clearly so
they can make the call, not to pretend the data settles it.

## 1. Frame the decision

Establish the team, format (T20, ODI/List A, first-class/Test) and the
role or slot in question. If the format isn't stated, use the team's most
recent format in the data and say so. Selection only considers players who
have played for that team in the simulated season.

## 2. Find the incumbent

The incumbent is whoever filled the role in the team's most recent match
of that format — for batting slots use batting position, for the
wicketkeeper use who took stumpings, for bowlers who bowled the overs. Say
how settled the role is (how many of the last five matches they filled it).

## 3. Gather the evidence (cricket_scorecards_analyst)

For the incumbent and every realistic alternative (players from the same
team who have batted in that part of the order, bowled in that format, or
kept wicket), pull the season figures relevant to the role and format:

- Top-order batting: runs, average, strike rate (strike rate matters most
  in T20, average most in first-class), pooled batting Match Factor.
- Bowling: wickets, average, economy (economy matters most in T20), pooled
  bowling Match Factor.
- Form: per-match Match Factor in their last five matches for that team.

Prefer players with a meaningful sample in that format (at least five
matches or innings) and flag any thin samples.

## 4. Check team balance

Apply conventional balance for the format and flag anything a change would
break:

- **T20:** two openers, a wicketkeeper, at least five genuine bowling
  options (six with all-rounders), a finisher in the lower middle order.
- **ODI / List A:** as T20, with five bowlers who can each bowl ten overs.
- **First-class / Test:** six specialist batters or five plus a batting
  all-rounder, a wicketkeeper, four or five bowlers able to take 20 wickets
  — usually three or four seamers and a spinner.

Bowling type (seam or spin, left or right arm) isn't in the simulated data.
Use web_search for a player's real-world bowling style when balance or
conditions depend on it, and say it comes from the web.

## 5. Present the decision

```
## <Role> for <team> — <format>

**Recommended: <player>** — <one-line reason grounded in the figures>
**Incumbent: <player>** — <figures; how settled the role is>
**Other options:**
- <player> — <figures; what they'd offer or cost>

**Balance check:** <what the recommendation does to keeper/bowling options,
or "no change to balance">

**If conditions favour…**
- seam/swing: <who moves up and why>
- spin: <…>
- a flat batting pitch: <…>
```

When the recommendation is the incumbent, say so and explain why the
alternatives don't displace them. All figures are from the 2026 simulated
season unless labelled as real-world background. When citing a Match
Factor, note that it's pooled over the season (1.0 = match average).
