-- Cortex Agent evaluation dataset for CRICKET_SCORECARDS_ANALYST.
--
-- Rebuilds the cases table and the CRICKET_AGENT_EVALSET dataset, in the
-- agent's schema. run_eval.sh runs it whenever this file has changed since
-- the last rebuild (it keeps a hash of the file in the table comment); to run
-- it by hand, USE SCHEMA first. Snowflake datasets can't be edited, so the
-- dataset is dropped and recreated. Git is the version history: every run is
-- named after its commit, so `git show <sha>:evals/cortex_agent/eval_cases.sql`
-- gives the cases a run was scored on.
--
-- The agent runs against live data that grows as scorecards land, so cases
-- test behaviour, following Snowflake's guidance for changing data: the
-- ground truth describes what a correct response should and shouldn't
-- contain. Only `fixed_fact` cases state exact figures, and only for things
-- new matches can't change: the completed Hampshire v Glamorgan match of
-- 1 May 2026, and April 2026 (all of its matches are loaded). Whether the
-- marts compute figures correctly is for the dbt tests; a fixed fact that
-- changes means dbt logic changed, which is worth knowing either way.
--
-- Categories:
--   out_of_scope     — data no tool has (toss, venue, ball-by-ball): answer
--                      without calling any tool
--   semantics        — the right calculation: averages per dismissal,
--                      economy per over, totals across a player's teams,
--                      pooled Match Factor, minimum samples
--   name_resolution  — surname only, unique and ambiguous
--   sim_vs_web       — simulated-season figures come from the data, never
--                      the web; career questions default to the simulation
--   web_context      — real-world background and pre-simulation history via
--                      web search, labelled and kept separate
--   skill            — player-profile, match-report, selector (including
--                      county candidates for an international side) and
--                      match-journalism (Markdown, then the newspaper-page
--                      offer), answered in text (no dashboard)
--   dashboard        — explicit requests for a visual; the only cases that
--                      expect code_execution
--   fixed_fact       — exact figures that can't change as data is added

CREATE OR REPLACE TABLE cricket_agent_eval_cases (
    case_id      VARCHAR,
    category     VARCHAR,
    input_query  VARCHAR,
    ground_truth VARIANT
);

INSERT INTO cricket_agent_eval_cases
SELECT column1, column2, column3, PARSE_JSON(column4)
FROM VALUES
    ('toss', 'out_of_scope',
     $$Who won the toss in the Hampshire v Glamorgan match on 1 May 2026?$$,
     $${"ground_truth_output": "The response should say that toss information isn't recorded in the data and may offer what is (result, scores, man of the match). It must not name a toss winner, infer one from which team batted first, or guess.",
        "ground_truth_invocations": []}$$),

    ('venue', 'out_of_scope',
     $$Where was the Hampshire v Glamorgan match on 1 May 2026 played?$$,
     $${"ground_truth_output": "The response should say that venue information isn't recorded in the data. It must not name a ground or infer one from the home team.",
        "ground_truth_invocations": []}$$),

    ('ball_by_ball', 'out_of_scope',
     $$What was the strike rate of batters in the death overs of T20 matches?$$,
     $${"ground_truth_output": "The response should say that ball-by-ball and phase data (powerplay, death overs) isn't in the data, so phase strike rates can't be calculated. It may offer overall T20 strike rates, but must not present them as death-overs figures.",
        "ground_truth_invocations": []}$$),

    ('batting_average_method', 'semantics',
     $$What is N Gubbins' batting average this season?$$,
     $${"ground_truth_output": "The response should give N Gubbins' runs, dismissals and batting average for the 2026 simulated season, with the average calculated as runs divided by dismissals (not by innings), and label the figures as the simulated season. It must not use web search or real-world figures.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('economy_method', 'semantics',
     $$What is B Kellaway's economy rate this season?$$,
     $${"ground_truth_output": "The response should give B Kellaway's economy rate for the 2026 simulated season as runs conceded per over, stating the runs conceded and overs it is based on. It must not use web search or real-world figures.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('totals_across_teams', 'semantics',
     $$Who has scored the most runs this season?$$,
     $${"ground_truth_output": "The response should rank players by total runs in the 2026 simulated season across all the teams each player appeared for: a player who played for both a county and a country is counted once, with their runs combined, not split by team. Players who didn't bat must not be ranked above those who did. It must not use web search.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('pooled_match_factor', 'semantics',
     $$Among bowlers with at least 30 wickets this season, who has the best bowling Match Factor?$$,
     $${"ground_truth_output": "The response should name the bowler with the highest pooled season bowling Match Factor among those with 30 or more wickets in the 2026 simulated season, using the pooled metric rather than an average of per-match values, and explain briefly that 1.0 is the match average and higher is better.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('minimum_sample', 'semantics',
     $$Who has the best batting average this season?$$,
     $${"ground_truth_output": "The response should apply a sensible minimum sample (for example a minimum number of innings or dismissals) and state the minimum it used, so the leader isn't a player with one or two innings. Averages must be runs divided by dismissals, for the 2026 simulated season.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('all_rounders', 'semantics',
     $$Who are the top 10 all-rounders, combining batting and bowling Match Factor, among players who batted and bowled in at least 5 matches?$$,
     $${"ground_truth_output": "The response should rank players by the combined pooled batting and pooled bowling Match Factor for the 2026 simulated season, limited to players who batted and bowled in at least 5 matches, and explain the composite briefly (each factor is 1.0 at the match average). It must not average per-match factors, and a list led by players with one or two outstanding matches indicates that it did.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('surname_unique', 'name_resolution',
     $$How many runs has Gubbins scored this season?$$,
     $${"ground_truth_output": "Only one player has the surname Gubbins, N Gubbins, so the response should answer for N Gubbins without asking which player is meant, giving his runs for the 2026 simulated season.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('surname_ambiguous', 'name_resolution',
     $$How many runs has Ali scored this season?$$,
     $${"ground_truth_output": "Several players have the surname Ali, including K Ali, M Ali, J Ali and H Ali. The response must recognise the name is ambiguous and either ask which Ali is meant or give the runs for each. It must not silently pick one player, and in particular must not assume M Ali because of a real-world cricketer of that name.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('sim_season_guard', 'sim_vs_web',
     $$How many wickets has J Porter taken this season, and for which team?$$,
     $${"ground_truth_output": "The response should give J Porter's wickets in the 2026 simulated season and his team (Essex), labelled as the simulated season. The figures must come from the data, not from real-world 2026 statistics or a web search.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('career_defaults_to_sim', 'sim_vs_web',
     $$How many career wickets has J Porter taken?$$,
     $${"ground_truth_output": "The response should default to the simulated season, giving J Porter's wickets for Essex in the 2026 simulated season, and signpost that his real-world record from before the simulation is separate and available if wanted. It must not add real-world figures to the simulated ones or present a combined career total.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('web_background', 'web_context',
     $$What kind of bowler is J Porter?$$,
     $${"ground_truth_output": "J Porter plays for Essex in the simulated data and is the real-world Jamie Porter, an Essex right-arm seam bowler (fast-medium). The bowling style must be labelled as real-world background from the web, with a source. Any simulated figures quoted must be labelled as the 2026 simulated season.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}, {"tool_name": "web_search"}]}$$),

    ('web_history', 'web_context',
     $$How did J Porter do before the simulated season started?$$,
     $${"ground_truth_output": "The response should describe Jamie Porter's real-world career before 2026: a long-serving Essex seam bowler and one of their leading first-class wicket-takers. Any figures must be labelled as real-world and pre-simulation, with a source, and kept separate from his 2026 simulated-season figures; they must not be added together.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}, {"tool_name": "web_search"}]}$$),

    ('skill_player_profile', 'skill',
     $$Give me a player profile of B Kellaway.$$,
     $${"ground_truth_output": "A text profile (no dashboard, since none was asked for) with two labelled, separate sections. The 2026 simulated season for Glamorgan: matches, batting and bowling figures, pooled batting and bowling Match Factors with a brief explanation, and recent form. Real-world background from the web: Ben Kellaway, a Glamorgan all-rounder known for bowling spin with either arm, with a source. No real-world figures may appear in the simulated-season section.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}, {"tool_name": "web_search"}]}$$),

    ('skill_match_report', 'skill',
     $$Write a match report for Hampshire v Glamorgan on 1 May 2026.$$,
     $${"ground_truth_output": "A text match report (no dashboard, since none was asked for). Hampshire beat Glamorgan by 135 runs in the first-class league. Hampshire made 733 runs for 19 wickets across their two innings; Glamorgan made 598 for 20. F Middleton was man of the match with 175 runs (69 and 106), a batting Match Factor of about 2.20. Key partnerships: 111 for Hampshire's 7th wicket in the first innings and an opening stand of 144 in the second. Innings must be kept separate. It must not mention or guess the toss, venue or weather.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('skill_selector', 'skill',
     $$Who should open the batting for Hampshire in their next T20?$$,
     $${"ground_truth_output": "A text recommendation (no dashboard, since none was asked for) structured as a recommended option, the incumbents and other options. The incumbents are the openers from Hampshire's most recent T20 in the data. It should compare candidates on T20 strike rate and average from the 2026 simulated season, show recent form as scores rather than single-match Match Factors, label any Match Factor as the pooled season figure, note any wicketkeeping implications for team balance, and offer options for different conditions for the selector to weigh. It must not invent figures.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('skill_selector_domestic', 'skill',
     $$Who should England bring in to open the batting in the next Test?$$,
     $${"ground_truth_output": "A text recommendation structured as a recommended option, the incumbents (the openers from England's most recent Test in the data) and other options. Candidates must include county players with strong English FC League (first-class) records from the 2026 simulated season, not only players who have already played for England, with domestic and Test figures shown separately and never combined. Eligibility for England, if mentioned, is labelled as real-world information from the web or flagged as unconfirmed. Any Match Factor is the pooled season figure, labelled as such. It must not invent figures.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}, {"tool_name": "web_search"}]}$$),

    ('skill_journalism', 'skill',
     $$Write a newspaper report of Hampshire v Glamorgan on 1 May 2026.$$,
     $${"ground_truth_output": "A broadsheet-style match report in Markdown in the reply (no HTML page yet): a headline that makes a judgement, an italic standfirst, a generic byline and dateline, several paragraphs of measured, analytical prose without hyperbole, and a scores-in-brief section, ending with the question \"Would you like this in newspaper format?\". It uses traditional figures (runs, balls, bowling figures, averages) and not Match Factor. Facts: Hampshire beat Glamorgan by 135 runs in the first-class league; Hampshire 733 for 19 across two innings, Glamorgan 598 for 20; F Middleton man of the match with 175 runs (69 and 106). It must not invent quotes, the toss, the venue or the weather, and must not be signed as or attributed to a real journalist.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('dashboard_match', 'dashboard',
     $$Show me a dashboard for the Hampshire v Glamorgan match on 1 May 2026.$$,
     $${"ground_truth_output": "Builds an HTML dashboard of the match with short accompanying text. The facts shown and stated must match the data: Hampshire beat Glamorgan by 135 runs in the first-class league; Hampshire 733 for 19 across two innings, Glamorgan 598 for 20; F Middleton man of the match with 175 runs (69 and 106). It must not show or guess the toss, venue or weather.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}, {"tool_name": "code_execution"}]}$$),

    ('dashboard_selection', 'dashboard',
     $$Can you chart Hampshire's T20 opening options for me?$$,
     $${"ground_truth_output": "Builds an HTML visual comparing Hampshire's T20 opening options on strike rate and average, with short accompanying text identifying the incumbents (the openers from Hampshire's most recent T20). All figures must come from the 2026 simulated season.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}, {"tool_name": "code_execution"}]}$$),

    ('match_result_motm', 'fixed_fact',
     $$Who won the match between Hampshire and Glamorgan on 1 May 2026, and who was man of the match?$$,
     $${"ground_truth_output": "Hampshire won by 135 runs. F Middleton was man of the match.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('team_partnerships', 'fixed_fact',
     $$What were Hampshire's batting partnerships on 1 May 2026?$$,
     $${"ground_truth_output": "Hampshire batted twice, and the response must keep the two innings separate rather than merging or summing partnerships with the same wicket number. First innings: the biggest stand was 111 for the 7th wicket, and the opening stand was 66. Second innings: the opening stand was 144, the biggest of the match. Listing every partnership is not required, but any numbers given must match the right innings.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('batting_match_factor', 'fixed_fact',
     $$What was F Middleton's batting Match Factor on 1 May 2026?$$,
     $${"ground_truth_output": "F Middleton's batting Match Factor on 1 May 2026 was about 2.20 (2.2 acceptable), roughly 2.2 times the average batting contribution in that match. It is a single-match figure.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('bowling_match_factor', 'fixed_fact',
     $$What was B Kellaway's bowling Match Factor on 1 May 2026?$$,
     $${"ground_truth_output": "B Kellaway's bowling Match Factor on 1 May 2026 was about 1.15 (1.1 to 1.15 acceptable), slightly above the average bowling contribution in that match. It is a single-match figure.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('team_match_totals', 'fixed_fact',
     $$What were Hampshire's total runs, wickets lost, and result against Glamorgan on 1 May 2026?$$,
     $${"ground_truth_output": "Hampshire scored 733 runs across both innings for the loss of 19 wickets, and won the match.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('april_matches_by_format', 'fixed_fact',
     $$How many matches were played in April 2026, broken down by format?$$,
     $${"ground_truth_output": "34 matches were played in April 2026: 29 first-class league, 3 ODIs and 2 T20 internationals. Format labels may be paraphrased. The count must cover April 2026 only.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('april_top_run_scorer', 'fixed_fact',
     $$Who scored the most runs in April 2026?$$,
     $${"ground_truth_output": "K Jennings scored the most runs in April 2026, 481. E Gay was second with 479, and H Hameed third with 474. Totals cover all of a player's teams and April 2026 only.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('april_top_wicket_taker', 'fixed_fact',
     $$Who took the most wickets in April 2026?$$,
     $${"ground_truth_output": "L P'n-White took the most wickets in April 2026, 23. J Porter was second with 22, and C Woakes third with 21. Totals cover April 2026 only.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$);

DROP DATASET IF EXISTS CRICKET_AGENT_EVALSET;

-- Snowflake's column_mapping key here is expected_tools, not ground_truth
-- (the YAML dataset block uses ground_truth — the two differ by design).
CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    CURRENT_DATABASE() || '.' || CURRENT_SCHEMA() || '.CRICKET_AGENT_EVAL_CASES',
    CURRENT_DATABASE() || '.' || CURRENT_SCHEMA() || '.CRICKET_AGENT_EVALSET',
    OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH')
);
