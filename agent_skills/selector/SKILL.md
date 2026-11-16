---
name: selector
description: Advises on team selection in text — who to pick for a role, a squad place or a full XI — covering the recommended option, the incumbent and other options (including county players for an international side), with conventional team balance and choices for different conditions. Use for "who should play/open/bowl/keep", "pick a side", "should X replace Y" and similar selection questions.
---

# Selector

The selector knows things the data doesn't — pitch, weather, opposition,
fitness. Lay out the evidence and the options clearly so they can make the
call; don't pretend the data settles it.

## 1. Frame the decision

Establish the team, format (T20, ODI/List A, first-class/Test) and the role
or slot in question. If the format isn't stated, use the team's most recent
format in the data and say so.

The data has two levels of cricket:

- **International:** Test, ODI and T20I (20 Over International) matches
  between countries.
- **Domestic (English county):** the English FC League (first-class), the
  Challenge Trophy (50 overs), the 20 Over Trophy (T20) and the 100 Ball
  Trophy (the Hundred, 100 balls an innings).

## 2. Find the incumbent

The incumbent is whoever filled the role in the team's most recent match of
that format — batting position for batting slots, stumpings for the
wicketkeeper, overs bowled for bowlers. Note how settled the role is (how
many of the last five matches they filled it).

## 3. Find the candidates

- **County side:** players who have played for that county this season.
- **International side:** players who have played for that country this
  season, **and** county players with a strong domestic record in the
  matching format — always look at both before recommending. Matching
  formats: Test ↔ English FC League; ODI ↔ Challenge Trophy and 20 Over
  Trophy combined; T20I ↔ 20 Over Trophy and 100 Ball Trophy combined.
  Combine them by pooling the raw figures (runs, balls, dismissals,
  wickets, runs conceded) and recomputing averages and rates, never by
  averaging each competition's averages, and show which competitions the
  figures come from. For a non-English country, say that domestic cricket
  outside England isn't in the data.

The data doesn't record nationality. For county candidates for England,
check eligibility with web_search (team plus surname, as in the
orchestration rules) and label it as from the web; if it can't be
confirmed, include the player with the flag "eligibility unconfirmed".
Leave out anyone confirmed as an overseas player.

## 4. Gather the evidence (cricket_scorecards_analyst)

Ask for everything below in as few analyst queries as possible — ideally
one for the team's own players and one for domestic candidates.

For the incumbent and every realistic alternative:

1. **Season figures in the format (and the matching domestic format for
   county candidates):** batting — innings, runs, average, strike rate,
   hundreds and fifties; bowling — matches, wickets, average, economy,
   strike rate; keeping — catches, stumpings.
2. **Pooled Match Factor for the season** in that format, labelled "season,
   pooled". Don't use single-match Match Factors in a selection answer.
3. **Recent form as scores and figures:** each candidate's last five
   innings (for example 45, 3, 67*, 12, 101) or bowling figures (for
   example 3-41, 0-28).

Strike rate and economy matter most in T20; average most in first-class.
Flag any candidate with fewer than five matches or innings in the format.
Domestic and international figures are different standards: show them in
separate columns and never add them together.

Bowling type (seam or spin, left or right arm) isn't in the simulated data.
When balance or conditions depend on it, use web_search for the player's
real-world bowling style and label it as from the web.

## 5. Check team balance

Apply conventional balance for the format:

- **T20:** two openers, a wicketkeeper, at least five genuine bowling
  options (six with all-rounders), a finisher in the lower middle order.
- **ODI / List A:** as T20, with five bowlers who can each bowl ten overs.
- **First-class / Test:** six specialist batters or five plus a batting
  all-rounder, a wicketkeeper, four or five bowlers able to take 20
  wickets — usually three or four seamers and a spinner.

## 6. Write the recommendation

Lead with a short comparison table (candidate, current team, level, key
figures for the format, season pooled Match Factor, last five scores or
figures, sample-size flag), then:

- **Recommended:** the pick and the one or two figures that justify it.
- **Incumbent:** their case, and why they do or don't keep the place.
- **Other options:** what each would offer or cost, including the best
  domestic candidates for an international side.
- **Balance:** anything the change breaks or fixes.
- **If conditions favour…** seam/swing, spin, or a flat batting pitch: who
  moves up and why, for the selector to weigh against what they know.

All figures are from the 2026 simulated season unless labelled as
real-world background.

If the user asked for a dashboard, chart or other visual, also follow the
dashboard skill using the results gathered above.
