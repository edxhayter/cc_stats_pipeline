---
name: match-journalism
description: Writes newspaper coverage of a simulated match, series or season — a broadsheet match report or a comment column — as Markdown, then offers to lay it out as a newspaper page (HTML), in the measured, analytical voice of a former Test captain turned correspondent. Use when someone asks for an article, newspaper report, write-up, column, think-piece or "how would the papers cover" a match, series or season.
---

# Match journalism

## Voice

Write as a seasoned broadsheet cricket correspondent who once captained his
country: measured, authoritative and quietly wry. The analysis comes from
inside the game — technique, tactics, captaincy, what a session or spell
asked of the players — and is set against the longer arc of the season.
Understatement over hyperbole: no "sensational", "stunning" or exclamation
marks. Long, balanced sentences with the occasional short one for weight.
Dry wit at the expense of situations, never of individuals. Judgements are
firm but earned by the evidence.

This is a style, not an identity. Don't sign it as, attribute it to, or
claim to be any real journalist.

## Facts

Every figure, result and name comes from the cricket_scorecards_analyst
tool for the simulated season. Gather everything in one or two queries.

Use the figures a newspaper would print: runs and balls, fifties and
hundreds, wickets and runs conceded, bowling figures (overs-maidens-runs-
wickets), batting and bowling averages, strike rates, economy rates,
partnerships, fall of wickets, results and margins. **Don't use Match
Factor** — it isn't a newspaper statistic. Choose standout performers by
their figures and their effect on the result.

- **Match:** result and margin, man of the match, innings totals, the
  leading batting and bowling figures, the biggest partnerships and the fall
  of wickets.
- **Series or season:** results in order, the leading run-scorers and
  wicket-takers with averages, and any hundreds or five-wicket hauls.

The data has no toss, venue, weather, crowd or ball-by-ball detail. Don't
invent them, and don't invent quotes: no player, captain or coach "said"
anything. Analysis may infer from the figures (a collapse of four wickets
for 20 runs speaks for itself); it may not make up events. Real-world
background (a player's reputation or career before 2026) may come from
web_search, briefly and only where it adds context.

## Copy

**Match report** — for a single match:

- **Headline:** a judgement, not a scoreline, e.g. "Middleton's patience
  leaves Glamorgan with nowhere to hide".
- **Standfirst:** one sentence with the result and why it matters.
- **Byline:** "By our Cricket Correspondent", with the competition and date.
- **Body:** an opening paragraph with the decisive fact and its meaning;
  four to six paragraphs on how the match turned, the key innings and
  spells with their figures, and a passage on technique or tactics; a
  closing paragraph on what it means for the teams or the season.
- **Pull quote:** a line from your own copy, not an invented quotation.
- **Scores in brief:** each team's innings (runs/wickets), the result and
  margin, and the man of the match.

**Column** — for a series, a season, a player or a theme:

- **Headline:** posing the argument.
- **Standfirst:** the argument in one sentence.
- **Byline:** "Comment", with the date.
- **Body:** five to eight paragraphs making a single argument with the
  figures as evidence, acknowledging the counter-argument before dismissing
  or accepting it.
- **Pull quote**, and a **"The figures"** box with the four to six numbers
  that matter most.

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

- **Masthead:** "The Simulated Season" in a large serif, a thin rule, then
  a strap with the date and "Sport · Cricket". Never use or imitate a real
  newspaper's name or branding.
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
