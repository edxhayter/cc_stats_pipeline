-- Cortex Agent evaluation dataset for CRICKET_SCORECARDS_ANALYST.
--
-- Run once per dataset version, in the same database/schema as the agent
-- (the semantic schema — see var.snowflake_semantic_schema). Snowflake
-- datasets are immutable: after changing any row below, bump the version
-- suffix in BOTH the CALL at the bottom and agent_evaluation_config.yaml.
--
-- Ground truth was taken from the dev marts with the full 173-match 2026
-- season loaded (2026-04-03 to 2026-06-28). Single-match cases are stable;
-- season-aggregate cases (category 'held_out_season') will drift as new
-- scorecards land and need refreshing alongside them.
--
-- Categories:
--   verified_query   — mirrors an AI_VERIFIED_QUERIES entry; should be easy
--   held_out_*       — no verified query covers it; tests generalisation
--   out_of_scope     — data the scorecards don't contain; the agent should
--                      say so and not call the tool

SET agent_schema_fqn = '<DATABASE>.<SEMANTIC_SCHEMA>';  -- same schema as the agent
USE SCHEMA IDENTIFIER($agent_schema_fqn);

CREATE OR REPLACE TABLE cricket_agent_eval_cases (
    case_id      VARCHAR,
    category     VARCHAR,
    input_query  VARCHAR,
    ground_truth VARIANT
);

INSERT INTO cricket_agent_eval_cases
SELECT column1, column2, column3, PARSE_JSON(column4)
FROM VALUES
    ('batting_average', 'verified_query',
     $$How many runs has N Gubbins scored, and what is his batting average?$$,
     $${"ground_truth_output": "N Gubbins has scored 852 runs with 22 dismissals, a batting average of 38.73 (38.7 or 38.73 acceptable). The average must be runs divided by dismissals, not by innings.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('bowler_wickets_economy', 'verified_query',
     $$How many wickets has B Kellaway taken, and what is his economy rate?$$,
     $${"ground_truth_output": "B Kellaway has taken 48 wickets. Economy rate is about 4.64 runs per over (1512 runs conceded over 326 overs); anything from 4.6 to 4.7 is acceptable.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('match_result_motm', 'verified_query',
     $$Who won the match between Hampshire and Glamorgan on 1 May 2026, and who was man of the match?$$,
     $${"ground_truth_output": "Hampshire won by 135 runs. F Middleton was man of the match.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('batting_match_factor', 'verified_query',
     $$What was F Middleton's batting Match Factor on 1 May 2026?$$,
     $${"ground_truth_output": "F Middleton's batting Match Factor on 1 May 2026 was about 2.20 (2.2 acceptable), meaning roughly 2.2 times the average batting contribution in that match.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('bowling_match_factor', 'verified_query',
     $$What was B Kellaway's bowling Match Factor on 1 May 2026?$$,
     $${"ground_truth_output": "B Kellaway's bowling Match Factor on 1 May 2026 was about 1.17 (1.17 or 1.2 acceptable), meaning slightly above the average bowling contribution in that match.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('team_partnerships', 'verified_query',
     $$What were Hampshire's batting partnerships on 1 May 2026?$$,
     $${"ground_truth_output": "Hampshire batted twice, and the response must keep the two innings separate rather than merging or summing partnerships with the same wicket number. First innings: the biggest stand was 111 for the 7th wicket, and the opening stand was 66. Second innings: the opening stand was 144, the biggest of the match. Listing every partnership is not required, but any numbers given must match the right innings.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('fielding', 'verified_query',
     $$How many catches and stumpings has F Middleton taken?$$,
     $${"ground_truth_output": "F Middleton has taken 12 catches and 0 stumpings.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('all_rounders', 'verified_query',
     $$Who are the top 10 all-rounders, combining batting and bowling Match Factor, among players who batted and bowled in at least 5 matches?$$,
     $${"ground_truth_output": "The top three are E Brookes (composite about 6.65), M Ali (about 3.94) and H Brook (about 3.64). The list should only include players with at least 5 matches where they both batted and bowled; single-match players such as J Smith must not appear.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('team_match_totals', 'verified_query',
     $$What were Hampshire's total runs, wickets lost, and result against Glamorgan on 1 May 2026?$$,
     $${"ground_truth_output": "Hampshire scored 733 runs across both innings for the loss of 19 wickets, and won the match.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('top_run_scorer', 'held_out_season',
     $$Who has scored the most runs this season?$$,
     $${"ground_truth_output": "E Gay has scored the most runs, 1292. A Hose is second with 1226. Players who did not bat (null runs) must not be ranked above them.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('top_wicket_taker', 'held_out_season',
     $$Who has taken the most wickets this season?$$,
     $${"ground_truth_output": "J Porter has taken the most wickets, 70. J Carson is second with 64.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('team_win_record', 'held_out_season',
     $$How many matches has Hampshire played and how many have they won?$$,
     $${"ground_truth_output": "Hampshire have played 16 matches and won 13.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('matches_by_format', 'held_out_season',
     $$How many matches are there in the data, broken down by format?$$,
     $${"ground_truth_output": "173 matches in total: FC_LEAGUE 72, T20 67, ODI 15, T20I 11, TEST 8. Format labels may be paraphrased (for example First Class League, T20 International).",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('player_match_runs', 'held_out_match',
     $$How many runs did F Middleton score against Glamorgan on 1 May 2026?$$,
     $${"ground_truth_output": "F Middleton scored 175 runs across his two innings in the match.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('opposition_total', 'held_out_match',
     $$How many runs did Glamorgan score in total against Hampshire on 1 May 2026?$$,
     $${"ground_truth_output": "Glamorgan scored 598 runs across their two innings.",
        "ground_truth_invocations": [{"tool_name": "cricket_scorecards_analyst"}]}$$),

    ('toss', 'out_of_scope',
     $$Who won the toss in the Hampshire v Glamorgan match on 1 May 2026?$$,
     $${"ground_truth_output": "The response should say that toss information is not in this dataset. It must not name a toss winner or guess.",
        "ground_truth_invocations": []}$$),

    ('venue', 'out_of_scope',
     $$Where was the Hampshire v Glamorgan match on 1 May 2026 played?$$,
     $${"ground_truth_output": "The response should say that venue information is not in this dataset. It must not name a ground or infer one from the home team.",
        "ground_truth_invocations": []}$$),

    ('ball_by_ball', 'out_of_scope',
     $$What was the strike rate of batters in the death overs of T20 matches?$$,
     $${"ground_truth_output": "The response should say that ball-by-ball or phase data (powerplay, death overs) is not in this dataset, so phase strike rates can't be calculated. It may offer overall T20 strike rates instead, but must not present them as death-overs figures.",
        "ground_truth_invocations": []}$$);

-- Snowflake's column_mapping key here is expected_tools, not ground_truth
-- (the YAML dataset block uses ground_truth — the two differ by design).
CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    CURRENT_DATABASE() || '.' || CURRENT_SCHEMA() || '.CRICKET_AGENT_EVAL_CASES',
    CURRENT_DATABASE() || '.' || CURRENT_SCHEMA() || '.CRICKET_AGENT_EVALSET_V1',
    OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH')
);
