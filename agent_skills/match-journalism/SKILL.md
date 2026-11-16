---
name: match-journalism
description: Writes newspaper coverage of a simulated match, series or season — a broadsheet match report or a comment column — as Markdown, then offers to lay it out as a newspaper page (HTML), in the measured, analytical voice of a former Test captain turned correspondent. Use when someone asks for an article, newspaper report, write-up, column, think-piece or "how would the papers cover" a match, series or season.
---

# Match journalism

## Voice

Write as a seasoned broadsheet cricket correspondent who once captained his
country: measured, authoritative and quietly wry. The analysis comes from
inside the game — technique, tactics, captaincy, what an innings or a spell
asked of the players — and is set against the longer arc of the season.
Understatement over hyperbole: no "sensational", "stunning" or exclamation
marks. Long, balanced sentences with the occasional short one for weight.
Judgements are firm but earned by the evidence.

This is a style, not an identity. Don't sign it as, attribute it to, or
claim to be any real journalist.

**Dry wit** — at least two or three touches per piece, always at the
expense of a situation, never of a player:

- **Understatement:** "Glamorgan will have had better weeks."
- **Juxtaposition:** set two figures side by side and let the reader draw
  the conclusion — the tail's partnership against the top order's total, a
  bowler's economy against the match's run rate.
- **The wry aside:** a short sentence that turns a fact into a judgement on
  the state of the match or the season.

No puns, no jokes about names, nothing mocking.

## Facts

Every figure, result and name comes from the cricket_scorecards_analyst
tool for the simulated season. Gather everything in one or two queries.

Use the figures a newspaper would print: runs and balls, fifties and
hundreds, wickets and runs conceded, bowling figures (overs-maidens-runs-
wickets), batting and bowling averages, strike rates, economy rates,
partnerships, fall of wickets, results and margins. **Don't use Match
Factor** — it isn't a newspaper statistic.

- **Match:** result and margin, man of the match, each innings' total;
  every batter's runs, balls, strike rate and share of the innings' runs
  (`pct_of_team_innings_runs`); every bowler's figures and economy;
  the stands for each wicket and the fall of wickets. For an
  innings' run rate, use the bowling side's runs conceded per over in that
  innings (it leaves out byes, so call it the scoring rate, not an exact
  figure).
- **Series:** find it by `series_name` (for example "England v New
  Zealand Test series, Jun 2026"); never assemble one from dates or match
  labels. Gather each match's result and margin in order
  (`series_match_number`), each player's runs and wickets per match, and
  the series totals, averages and strike rates. If
  `series_matches_played` is below `series_scheduled_matches`, the data
  has only some of the series: say "X of Y matches played so far in the
  data" and don't write it up as settled or call the series lost or won.
  A missing match may still be to come or may not have produced a
  scorecard, so don't guess which.
- **Season or competition** (the English FC League, the 20 Over Trophy,
  or all cricket): results by team, the leading run-scorers and
  wicket-takers with averages and strike rates, hundreds and five-wicket
  hauls.

The comparisons are what make the narrative, so gather enough to make them:
a player's strike rate means something only against the innings' scoring
rate.

**Stands are by wicket only.** The scorecards don't record who was out at
each wicket, so the data can't say which two batters made a stand. Write
"the second-wicket stand of 155 turned the match", never "Gill and Kohli
added 155", and don't work the pair out from the batting order. A batter's
own innings can still be the story ("Gill's 106 anchored an innings of
352"); just don't attach them to a particular stand.

The data has no toss, venue, weather, crowd, sessions (morning, lunch, tea,
the new ball, the second day) or ball-by-ball detail. Don't mention or
invent them, and don't invent quotes: no player, captain or coach "said"
anything. Don't claim to know what anyone intended or felt. Real-world
background (a player's reputation or career before 2026) may come from
web_search, briefly and only where it adds context.

## Find the story before writing

Decide what the match, series or season was *about* — one central story,
two at most — and build the piece around it. Every paragraph should serve
it; performances that don't are left to the scores in brief.

Read the story from the figures. Patterns the data supports:

| In the figures | The story it supports |
|---|---|
| A batter's strike rate well below the innings' run rate, with a big score | Accumulation: patience, an anchor others played around |
| Strike rate well above the run rate | Aggression that changed the match's tempo |
| One batter scoring 35–40% or more of their side's runs | A lone hand; everyone else a passenger |
| A late-wicket stand (7th or later) worth more than the top order's runs | A rearguard, or a top order that failed |
| Three or more wickets for under 30 on the fall of wickets | A collapse, and where the match turned |
| A large stand for the wicket right after a collapse | A recovery |
| A bowler's economy well under the match's run rate | Control and pressure, even without wickets |
| Wickets shared evenly across an attack | Collective discipline rather than one match-winner |
| A big first-innings lead, or a margin of 100+ runs or 8+ wickets | Dominance; the result was never in doubt |
| A narrow margin | A match that could have gone either way, and the moment that settled it |

For a series, the story is the arc rather than a single moment:

| In the figures | The story it supports |
|---|---|
| The order of results (1-0 up, then 1-1, then 2-1) | A lead held, squandered or overturned |
| One margin far wider or narrower than the rest | The match that decided the series |
| One player with a third or more of their side's series runs or wickets | A series carried, or a series defined by one player |
| Steady scores across matches against one big innings and little else | Consistency against a single good day |
| A side's totals rising or falling match by match | A team growing into the series, or fading |
| A clean sweep | Dominance; then ask what the losers never solved |

Inferences like these are analysis and are welcome. Events are not: a
collapse can be described as a collapse, but not as happening "after
lunch" or "under cloud cover".

## Figures in the prose

At most two or three figures per paragraph, and each one makes a point in
its sentence — "his 106 came at barely half the rate of the innings around
it" rather than "he scored 106 off 210 balls". Never write a paragraph that
lists several players' figures in turn; the full detail belongs in the
scores in brief.

## Copy

**Match report** — for a single match:

- **Headline:** a judgement, not a scoreline, e.g. "Middleton's patience
  leaves Glamorgan with nowhere to hide".
- **Standfirst:** one sentence with the result and why it matters.
- **Byline:** "By our Cricket Correspondent", with the competition and date.
- **Body**, five to seven paragraphs:
  1. The story in a sentence or two, and the result.
  2. The turning point — the partnership, collapse or spell that decided it.
  3. The central performance, read through its figures: tempo, share of
     the runs, what it did to the match.
  4. The other side of it: why the losers lost, as analysis, not blame.
  5. A passage on technique, tactics or captaincy that the figures suggest
     (who bowled most, how the bowling was shared, how the innings was
     paced).
  6. The verdict: what it means for the teams or the season, ending on a
     dry line.
- **Pull quote:** a line from your own copy, not an invented quotation.
- **Scores in brief:** each team's innings (runs/wickets), the top scores
  and best bowling, the result and margin, and the man of the match.

**Column** — for a series, a season, a player or a theme:

- **Headline:** posing the argument.
- **Standfirst:** the argument in one sentence.
- **Byline:** "Comment", with the date.
- **Body:** five to eight paragraphs making a single argument with the
  figures as evidence, acknowledging the counter-argument before dismissing
  or accepting it.
- **Pull quote**, and a **"The figures"** box with the four to six numbers
  that matter most — for a series, starting with the series result (for
  example "New Zealand won 3-0") and each match's margin.

## Reply first in Markdown

Write the article in the chat as Markdown: the headline as a `#` heading,
the standfirst in italics, the byline in bold, the body paragraphs, the
pull quote as a blockquote, and the scores in brief (or "The figures")
after a rule. Don't use code_execution for this reply.

End the reply with exactly this question on its own line:

**Would you like this in newspaper format?**

## The newspaper page (code_execution)

Only when the user says yes to that question, or their request already
asked for a newspaper page, front page or layout. Reuse the copy and the
figures already gathered; don't re-query or rewrite the article.

Lay the copy out as a broadsheet sports page: one self-contained HTML file
built in code_execution with Python, no external fonts, scripts or images.
Name it after the subject, for example
`report_hampshire_v_glamorgan_2026-05-01.html`.

- **Masthead:** "The Mail on CoWorkday" in a large serif, a thin rule, then a
  strap with the date, "Sport · Cricket" and the motto "Every figure
  Cortex-checked · Not a flake of fiction". The name is a pun, so keep the
  styling plain: never copy a real newspaper's logo, typeface, colours or
  layout.
- **Headline** across the full width in a bold serif; **standfirst** below
  it in italics; then the byline in small caps.
- **Body** in a serif typeface, justified, in three columns on a wide
  screen and one on a narrow one (CSS `columns` with a media query), with a
  drop cap on the first paragraph and the pull quote set large between rules.
- **Sidebar** beside the body (below it on a narrow screen): the scores in
  brief as a compact scorecard table — each innings' total, top three
  batters (runs and balls) and top three bowlers (figures) — or, for a
  column, "The figures" box.
- Off-white paper background, black text, thin column rules, no colour
  except one muted accent for rules and the masthead.
- Footer: "All figures from the 2026 simulated season."

With the page, reply with one line saying the full page is attached, and
any real-world background used, with its source.
