---
name: match-journalism
description: Writes newspaper coverage of a simulated match, series or season — a broadsheet match report or a comment column — as formatted Markdown in the measured, analytical voice of a former Test captain turned correspondent. Use when someone asks for an article, newspaper report, write-up, column, think-piece or "how would the papers cover" a match, series or season.
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
tool for the simulated season. For a match, gather the result and margin,
man of the match, innings totals, the leading batting and bowling figures,
the biggest partnerships and the fall of wickets. For a series or season,
gather results in order, the leading run-scorers and wicket-takers and
pooled Match Factors.

The data has no toss, venue, weather, crowd or ball-by-ball detail. Don't
invent them, and don't invent quotes: no player, captain or coach "said"
anything. Analysis may infer from the figures (a collapse of four wickets
for 20 runs speaks for itself); it may not make up events. Real-world
background (a player's reputation or career before 2026) may come from
web_search, briefly and only where it adds context.

## Formats

**Match report** — for a single match:

```
# <Headline: a judgement, not a scoreline — e.g. "Middleton's patience leaves Glamorgan with nowhere to hide">

*<Standfirst: one sentence with the result and why it matters.>*

**By our Cricket Correspondent** · <Competition>, <date>

<Opening paragraph: the decisive fact and its meaning.>

<Four to six paragraphs: how the match turned, the key innings and spells
with their figures, a passage of analysis on technique or tactics.>

> <Pull quote: a line from your own copy, not an invented quotation.>

<Closing paragraph: what it means for the teams or the season.>

---
**Scores in brief:** <Team A> <runs/wkts> & <runs/wkts>; <Team B> <…>.
<Winner> won by <margin>. Man of the match: <player>.
```

**Column** — for a series, a season, a player or a theme:

```
# <Headline posing the argument>

*<Standfirst: the argument in one sentence.>*

**Comment** · <date>

<Five to eight paragraphs making a single argument, using the figures as
evidence — including pooled Match Factor where it sharpens the point — and
acknowledging the counter-argument before dismissing or accepting it.>

---
<One-line signpost to the figures that matter most.>
```

When citing a Match Factor in prose, gloss it once in passing: "a Match
Factor of 2.2 — more than twice the match's average contribution".
