---
name: selector
description: Advises on team selection in text — who to pick for a role, a squad place or a full XI — covering the recommended option, the incumbent and other options, with conventional team balance and choices for different conditions. Use for "who should play/open/bowl/keep", "pick a side", "should X replace Y" and similar selection questions.
---

# Selector

The selector knows things the data doesn't — pitch, weather, opposition,
fitness. Lay out the evidence and the options clearly so they can make the
call; don't pretend the data settles it.

## 1. Frame the decision

Establish the team, format (T20, ODI/List A, first-class/Test) and the role
or slot in question. If the format isn't stated, use the team's most recent
format in the data and say so. Only consider players who have played for
that team in the simulated season.

## 2. Find the incumbent

The incumbent is whoever filled the role in the team's most recent match of
that format — batting position for batting slots, stumpings for the
wicketkeeper, overs bowled for bowlers. Note how settled the role is (how
many of the last five matches they filled it).

## 3. Gather the evidence (cricket_scorecards_analyst)

For the incumbent and every realistic alternative (players from the same
team who have batted in that part of the order, bowled in that format or
kept wicket):

1. **Season figures in that format:** top-order batting — innings, runs,
   average, strike rate, pooled batting Match Factor; bowling — matches,
   wickets, average, economy, pooled bowling Match Factor; keeping —
   catches, stumpings.
2. **Recent form:** per-match Match Factor in each candidate's last five
   matches for that team.

Strike rate and economy matter most in T20; average most in first-class.
Flag any candidate with fewer than five matches or innings in the format.

Bowling type (seam or spin, left or right arm) isn't in the simulated data.
When balance or conditions depend on it, use web_search for the player's
real-world bowling style and label it as from the web.

## 4. Check team balance

Apply conventional balance for the format:

- **T20:** two openers, a wicketkeeper, at least five genuine bowling
  options (six with all-rounders), a finisher in the lower middle order.
- **ODI / List A:** as T20, with five bowlers who can each bowl ten overs.
- **First-class / Test:** six specialist batters or five plus a batting
  all-rounder, a wicketkeeper, four or five bowlers able to take 20
  wickets — usually three or four seamers and a spinner.

## 5. Write the recommendation

Lead with a short comparison table (candidate, key figures for the format,
pooled Match Factor, last-five form, sample-size flag), then:

- **Recommended:** the pick and the one or two figures that justify it.
- **Incumbent:** their case, and why they do or don't keep the place.
- **Other options:** what each would offer or cost.
- **Balance:** anything the change breaks or fixes.
- **If conditions favour…** seam/swing, spin, or a flat batting pitch: who
  moves up and why, for the selector to weigh against what they know.

All figures are from the 2026 simulated season unless labelled as
real-world background.

If the user asked for a dashboard, chart or other visual, also follow the
dashboard skill using the results gathered above.
