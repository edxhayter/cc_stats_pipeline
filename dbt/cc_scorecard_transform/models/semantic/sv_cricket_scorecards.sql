-- Snowflake Semantic View for Cortex Analyst, built via the
-- Snowflake-Labs/dbt_semantic_view package (materialized='semantic_view'
-- executes CREATE SEMANTIC VIEW under the hood). References the existing
-- marts via ref() for correct dbt dependency tracking.
--
-- Scope: full star schema — dim_team, dim_player, dim_match, fact_batting,
-- fact_bowling, fact_fow, fact_partnership, fact_fielding, plus the two
-- match-summary marts (fact_player_match_summary, fact_team_match_summary).
-- Milestones live as count columns on fact_player_match_summary, not a
-- separate table. Season/competition rollups and the all-rounder composite
-- are METRICS here, not physical marts — deliberately deferred to this
-- layer (see docs/dbt-modeling-plan.md, "Rolling aggregates").
--
-- dim_team and dim_player are each referenced multiple times with
-- different aliases (role-playing dimensions) since the same physical
-- dimension plays different roles across the star schema — e.g. a team
-- can be the home team, away team, winner, batting side, or bowling side
-- depending on which relationship you're looking at.
--
-- Known simplification: fact_bowling.overs is summed as a naive decimal
-- (7.4 means 7 overs + 4 balls, not 7.4 decimal overs), so
-- total_overs_naive / economy_rate are approximations, not exact. Refine
-- later by converting to total balls bowled.
--
-- Match Factor over a period (season, competition, opposition, career) is
-- POOLED from the per-match ingredients on fact_player_match_summary
-- (mf_* facts), not averaged from the per-match factors — an average lets
-- one cheap wicket count as much as a season's work. Pooling uses the same
-- +1 blend as the per-match bowling factor (one extra wicket/dismissal at
-- the peer average), so a one-match period matches the per-match value and
-- tiny periods stay finite. Bowling is NULL with no wickets in the period.
-- See docs/dbt-modeling-plan.md, "Advanced metrics: Match Factor".
--
-- all_rounder_composite is pooled batting + pooled bowling Match Factor —
-- both are peer-normalised to 1.0 = average, so >2.0 reads as "better than
-- average at both disciplines combined".

{{ config(materialized='semantic_view') }}

TABLES (
    {{ ref('dim_match') }} PRIMARY KEY (match_id),
    home_teams AS {{ ref('dim_team') }} PRIMARY KEY (team_id),
    away_teams AS {{ ref('dim_team') }} PRIMARY KEY (team_id),
    winning_teams AS {{ ref('dim_team') }} PRIMARY KEY (team_id),
    batting_teams AS {{ ref('dim_team') }} PRIMARY KEY (team_id),
    bowling_teams AS {{ ref('dim_team') }} PRIMARY KEY (team_id),
    batters AS {{ ref('dim_player') }} PRIMARY KEY (player_id),
    bowlers AS {{ ref('dim_player') }} PRIMARY KEY (player_id),
    motm_players AS {{ ref('dim_player') }} PRIMARY KEY (player_id),
    partnership_batter_1 AS {{ ref('dim_player') }} PRIMARY KEY (player_id),
    partnership_batter_2 AS {{ ref('dim_player') }} PRIMARY KEY (player_id),
    fielders AS {{ ref('dim_player') }} PRIMARY KEY (player_id),
    summary_players AS {{ ref('dim_player') }} PRIMARY KEY (player_id),
    summary_teams AS {{ ref('dim_team') }} PRIMARY KEY (team_id),
    summary_opposition_teams AS {{ ref('dim_team') }} PRIMARY KEY (team_id),
    {{ ref('fact_batting') }},
    {{ ref('fact_bowling') }},
    {{ ref('fact_fow') }},
    {{ ref('fact_partnership') }},
    {{ ref('fact_fielding') }},
    {{ ref('fact_player_match_summary') }},
    {{ ref('fact_team_match_summary') }}
)

RELATIONSHIPS (
    dim_match (home_team_id) REFERENCES home_teams (team_id),
    dim_match (away_team_id) REFERENCES away_teams (team_id),
    dim_match (winning_team_id) REFERENCES winning_teams (team_id),
    dim_match (man_of_the_match_id) REFERENCES motm_players (player_id),
    fact_batting (match_id) REFERENCES dim_match (match_id),
    fact_batting (player_id) REFERENCES batters (player_id),
    fact_batting (team_id) REFERENCES batting_teams (team_id),
    fact_batting (opposition_team_id) REFERENCES bowling_teams (team_id),
    fact_bowling (match_id) REFERENCES dim_match (match_id),
    fact_bowling (player_id) REFERENCES bowlers (player_id),
    fact_bowling (team_id) REFERENCES bowling_teams (team_id),
    fact_bowling (opposition_team_id) REFERENCES batting_teams (team_id),
    fact_fow (match_id) REFERENCES dim_match (match_id),
    fact_fow (team_id) REFERENCES batting_teams (team_id),

    fact_partnership (match_id) REFERENCES dim_match (match_id),
    fact_partnership (team_id) REFERENCES batting_teams (team_id),
    fact_partnership (batter_1_id) REFERENCES partnership_batter_1 (player_id),
    fact_partnership (batter_2_id) REFERENCES partnership_batter_2 (player_id),

    fact_fielding (match_id) REFERENCES dim_match (match_id),
    fact_fielding (team_id) REFERENCES batting_teams (team_id),
    fact_fielding (batter_id) REFERENCES batters (player_id),
    fact_fielding (fielder_id) REFERENCES fielders (player_id),
    fact_fielding (bowler_id) REFERENCES bowlers (player_id),

    fact_player_match_summary (match_id) REFERENCES dim_match (match_id),
    fact_player_match_summary (player_id) REFERENCES summary_players (player_id),
    fact_player_match_summary (team_id) REFERENCES summary_teams (team_id),
    fact_player_match_summary (opposition_team_id) REFERENCES summary_opposition_teams (team_id),

    fact_team_match_summary (match_id) REFERENCES dim_match (match_id),
    fact_team_match_summary (team_id) REFERENCES summary_teams (team_id),
    fact_team_match_summary (opposition_team_id) REFERENCES summary_opposition_teams (team_id)
)

FACTS (
    fact_batting.runs AS fact_batting.runs,
    fact_batting.balls_faced AS fact_batting.balls_faced,
    fact_batting.fours AS fact_batting.fours,
    fact_batting.sixes AS fact_batting.sixes,
    fact_batting.strike_rate AS fact_batting.strike_rate,
    fact_batting.pct_of_team_innings_runs AS fact_batting.pct_of_team_innings_runs,

    fact_bowling.overs AS fact_bowling.overs,
    fact_bowling.maidens AS fact_bowling.maidens,
    fact_bowling.dots_bowled AS fact_bowling.dots_bowled,
    fact_bowling.runs_conceded AS fact_bowling.runs_conceded,
    fact_bowling.wickets AS fact_bowling.wickets,
    fact_bowling.economy AS fact_bowling.economy,
    fact_bowling.pct_of_team_innings_wickets AS fact_bowling.pct_of_team_innings_wickets,
    fact_batting.batting_match_factor AS fact_batting.batting_match_factor,
    fact_bowling.bowling_match_factor AS fact_bowling.bowling_match_factor,

    fact_fow.cumulative_score AS fact_fow.cumulative_score,

    fact_partnership.partnership_runs AS fact_partnership.partnership_runs,

    dim_match.result_margin_value AS dim_match.result_margin_value,

    fact_player_match_summary.total_runs AS fact_player_match_summary.total_runs,
    fact_player_match_summary.total_balls_faced AS fact_player_match_summary.total_balls_faced,
    fact_player_match_summary.total_fours AS fact_player_match_summary.total_fours,
    fact_player_match_summary.total_sixes AS fact_player_match_summary.total_sixes,
    fact_player_match_summary.dismissals AS fact_player_match_summary.dismissals,
    fact_player_match_summary.centuries AS fact_player_match_summary.centuries,
    fact_player_match_summary.half_centuries AS fact_player_match_summary.half_centuries,
    fact_player_match_summary.batting_match_factor AS fact_player_match_summary.batting_match_factor,
    fact_player_match_summary.total_overs_naive AS fact_player_match_summary.total_overs_naive,
    fact_player_match_summary.total_runs_conceded AS fact_player_match_summary.total_runs_conceded,
    fact_player_match_summary.total_wickets AS fact_player_match_summary.total_wickets,
    fact_player_match_summary.five_wicket_hauls AS fact_player_match_summary.five_wicket_hauls,
    fact_player_match_summary.bowling_match_factor AS fact_player_match_summary.bowling_match_factor,
    fact_player_match_summary.mf_bat_own_runs AS fact_player_match_summary.mf_bat_own_runs,
    fact_player_match_summary.mf_bat_own_dismissals AS fact_player_match_summary.mf_bat_own_dismissals,
    fact_player_match_summary.mf_bat_peer_runs AS fact_player_match_summary.mf_bat_peer_runs,
    fact_player_match_summary.mf_bat_peer_dismissals AS fact_player_match_summary.mf_bat_peer_dismissals,
    fact_player_match_summary.mf_bowl_own_runs_conceded AS fact_player_match_summary.mf_bowl_own_runs_conceded,
    fact_player_match_summary.mf_bowl_own_wickets AS fact_player_match_summary.mf_bowl_own_wickets,
    fact_player_match_summary.mf_bowl_peer_runs_conceded AS fact_player_match_summary.mf_bowl_peer_runs_conceded,
    fact_player_match_summary.mf_bowl_peer_wickets AS fact_player_match_summary.mf_bowl_peer_wickets,
    fact_player_match_summary.catches AS fact_player_match_summary.catches,
    fact_player_match_summary.stumpings AS fact_player_match_summary.stumpings,

    fact_team_match_summary.total_runs AS fact_team_match_summary.total_runs,
    fact_team_match_summary.total_wickets_lost AS fact_team_match_summary.total_wickets_lost,
    fact_team_match_summary.total_overs_faced_naive AS fact_team_match_summary.total_overs_faced_naive,
    fact_team_match_summary.total_runs_conceded AS fact_team_match_summary.total_runs_conceded,
    fact_team_match_summary.total_wickets_taken AS fact_team_match_summary.total_wickets_taken
)

DIMENSIONS (
    dim_match.match_date AS dim_match.match_date,
    dim_match.competition_name AS dim_match.competition_name,
    dim_match.competition_variant AS dim_match.competition_variant,
    dim_match.match_format AS dim_match.match_format,
    dim_match.result_type AS dim_match.result_type,
    dim_match.result_margin_type AS dim_match.result_margin_type,

    home_teams.team_name AS home_teams.team_name,
    away_teams.team_name AS away_teams.team_name,
    winning_teams.team_name AS winning_teams.team_name,
    batting_teams.team_name AS batting_teams.team_name,
    bowling_teams.team_name AS bowling_teams.team_name,

    batters.player_name AS batters.player_name,
    bowlers.player_name AS bowlers.player_name,
    motm_players.player_name AS motm_players.player_name,

    fact_batting.team_innings_number AS fact_batting.team_innings_number,
    fact_batting.match_innings_sequence AS fact_batting.match_innings_sequence,
    fact_batting.batting_position AS fact_batting.batting_position,
    fact_batting.dismissal_type AS fact_batting.dismissal_type,

    fact_bowling.team_innings_number AS fact_bowling.team_innings_number,
    fact_bowling.match_innings_sequence AS fact_bowling.match_innings_sequence,

    fact_fow.wicket_number AS fact_fow.wicket_number,

    fact_partnership.team_innings_number AS fact_partnership.team_innings_number,
    fact_partnership.partnership_number AS fact_partnership.partnership_number,
    fact_partnership.how_ended AS fact_partnership.how_ended,
    partnership_batter_1.player_name AS partnership_batter_1.player_name,
    partnership_batter_2.player_name AS partnership_batter_2.player_name,

    fact_fielding.dismissal_type AS fact_fielding.dismissal_type,
    fact_fielding.caught_and_bowled AS fact_fielding.caught_and_bowled,
    fielders.player_name AS fielders.player_name,

    summary_players.player_name AS summary_players.player_name,
    summary_teams.team_name AS summary_teams.team_name,
    summary_opposition_teams.team_name AS summary_opposition_teams.team_name,
    fact_player_match_summary.is_man_of_the_match AS fact_player_match_summary.is_man_of_the_match,

    fact_team_match_summary.batted_first AS fact_team_match_summary.batted_first,
    fact_team_match_summary.won AS fact_team_match_summary.won
)

METRICS (
    fact_batting.total_runs AS SUM(fact_batting.runs),
    fact_batting.total_balls_faced AS SUM(fact_batting.balls_faced),
    fact_batting.total_fours AS SUM(fact_batting.fours),
    fact_batting.total_sixes AS SUM(fact_batting.sixes),
    fact_batting.dismissals AS SUM(
        CASE
            WHEN fact_batting.dismissal_type NOT IN ('NOT_OUT', 'DID_NOT_BAT', 'RETIRED_HURT') THEN 1
            ELSE 0
        END
    ),
    fact_batting.innings_count AS COUNT(fact_batting.runs),
    fact_batting.batting_average AS fact_batting.total_runs / NULLIF(fact_batting.dismissals, 0),
    fact_batting.batting_strike_rate AS fact_batting.total_runs / NULLIF(fact_batting.total_balls_faced, 0) * 100,

    fact_bowling.total_runs_conceded AS SUM(fact_bowling.runs_conceded),
    fact_bowling.total_wickets AS SUM(fact_bowling.wickets),
    fact_bowling.total_overs_naive AS SUM(fact_bowling.overs),
    fact_bowling.economy_rate AS fact_bowling.total_runs_conceded / NULLIF(fact_bowling.total_overs_naive, 0),
    fact_bowling.bowling_average AS fact_bowling.total_runs_conceded / NULLIF(fact_bowling.total_wickets, 0),

    dim_match.matches_count AS COUNT(dim_match.match_date),

    fact_partnership.total_partnership_runs AS SUM(fact_partnership.partnership_runs),
    fact_partnership.avg_partnership_runs AS AVG(fact_partnership.partnership_runs),

    fact_fielding.total_catches AS SUM(
        CASE WHEN fact_fielding.dismissal_type = 'CAUGHT' THEN 1 ELSE 0 END
    ),
    fact_fielding.total_stumpings AS SUM(
        CASE WHEN fact_fielding.dismissal_type = 'STUMPED' THEN 1 ELSE 0 END
    ),

    fact_player_match_summary.matches_played AS COUNT(fact_player_match_summary.match_id),
    fact_player_match_summary.sum_total_runs AS SUM(fact_player_match_summary.total_runs),
    fact_player_match_summary.sum_dismissals AS SUM(fact_player_match_summary.dismissals),
    fact_player_match_summary.sum_centuries AS SUM(fact_player_match_summary.centuries),
    fact_player_match_summary.sum_five_wicket_hauls AS SUM(fact_player_match_summary.five_wicket_hauls),
    fact_player_match_summary.pooled_batting_match_factor AS
        ((SUM(fact_player_match_summary.mf_bat_own_runs)
            + SUM(fact_player_match_summary.mf_bat_peer_runs) / NULLIF(SUM(fact_player_match_summary.mf_bat_peer_dismissals), 0))
          / (SUM(fact_player_match_summary.mf_bat_own_dismissals) + 1))
        / NULLIF(SUM(fact_player_match_summary.mf_bat_peer_runs) / NULLIF(SUM(fact_player_match_summary.mf_bat_peer_dismissals), 0), 0),
    fact_player_match_summary.batting_match_factor_stddev AS STDDEV(fact_player_match_summary.batting_match_factor),
    fact_player_match_summary.pooled_bowling_match_factor AS
        CASE WHEN SUM(fact_player_match_summary.mf_bowl_own_wickets) > 0 THEN
            (SUM(fact_player_match_summary.mf_bowl_peer_runs_conceded) / NULLIF(SUM(fact_player_match_summary.mf_bowl_peer_wickets), 0))
            / NULLIF((SUM(fact_player_match_summary.mf_bowl_own_runs_conceded)
                + SUM(fact_player_match_summary.mf_bowl_peer_runs_conceded) / NULLIF(SUM(fact_player_match_summary.mf_bowl_peer_wickets), 0))
              / (SUM(fact_player_match_summary.mf_bowl_own_wickets) + 1), 0)
        END,
    fact_player_match_summary.bowling_match_factor_stddev AS STDDEV(fact_player_match_summary.bowling_match_factor),
    fact_player_match_summary.all_rounder_composite AS
        fact_player_match_summary.pooled_batting_match_factor + fact_player_match_summary.pooled_bowling_match_factor,

    fact_team_match_summary.matches_played AS COUNT(fact_team_match_summary.match_id),
    fact_team_match_summary.wins AS SUM(CASE WHEN fact_team_match_summary.won THEN 1 ELSE 0 END),
    fact_team_match_summary.sum_total_runs AS SUM(fact_team_match_summary.total_runs),
    fact_team_match_summary.sum_total_wickets_taken AS SUM(fact_team_match_summary.total_wickets_taken)
)

-- Curated question+SQL pairs that improve Cortex Analyst's accuracy on the
-- question shapes users actually ask. Two rules, both easy to get wrong:
--   1. SQL references the LOGICAL table names declared in TABLES above
--      (fact_batting, batters, winning_teams, ...), not physical tables via
--      ref() — per Snowflake's semantic view docs. Role-playing aliases make
--      this read naturally (JOIN batters, JOIN bowlers, JOIN fielders).
--   2. QUESTION names the same concrete values the SQL filters on. A generic
--      "a specific player" question paired with SQL hardcoding 'N Gubbins'
--      teaches the model the wrong mapping.
-- Each SQL was validated by running its physical-table equivalent against
-- the dev marts. The data is the full 173-match 2026 season, so career
-- totals here differ from the single-match Ham v Glm numbers in the docs.
AI_VERIFIED_QUERIES (
    batting_average_for_player AS (
        QUESTION 'What is N Gubbins'' batting average?'
        SQL 'SELECT b.player_name, SUM(fb.runs) AS total_runs, SUM(CASE WHEN fb.dismissal_type NOT IN (''NOT_OUT'', ''DID_NOT_BAT'', ''RETIRED_HURT'') THEN 1 ELSE 0 END) AS dismissals, SUM(fb.runs) / NULLIF(SUM(CASE WHEN fb.dismissal_type NOT IN (''NOT_OUT'', ''DID_NOT_BAT'', ''RETIRED_HURT'') THEN 1 ELSE 0 END), 0) AS batting_average FROM fact_batting AS fb JOIN batters AS b ON fb.player_id = b.player_id WHERE b.player_name = ''N Gubbins'' GROUP BY b.player_name'
    ),
    wickets_and_economy_for_bowler AS (
        QUESTION 'How many wickets has B Kellaway taken, and what is his economy rate?'
        SQL 'SELECT bo.player_name, SUM(bw.wickets) AS total_wickets, SUM(bw.runs_conceded) / NULLIF(SUM(bw.overs), 0) AS economy_rate FROM fact_bowling AS bw JOIN bowlers AS bo ON bw.player_id = bo.player_id WHERE bo.player_name = ''B Kellaway'' GROUP BY bo.player_name'
    ),
    match_result_and_motm AS (
        QUESTION 'Who won the match between Hampshire and Glamorgan on 1 May 2026, by what margin, and who was man of the match?'
        SQL 'SELECT wt.team_name AS winning_team, m.result_margin_type, m.result_margin_value, mp.player_name AS man_of_the_match FROM dim_match AS m JOIN home_teams AS ht ON m.home_team_id = ht.team_id JOIN away_teams AS at ON m.away_team_id = at.team_id LEFT JOIN winning_teams AS wt ON m.winning_team_id = wt.team_id LEFT JOIN motm_players AS mp ON m.man_of_the_match_id = mp.player_id WHERE ht.team_name = ''Hampshire'' AND at.team_name = ''Glamorgan'' AND m.match_date = ''2026-05-01'''
    ),
    batting_match_factor_for_player AS (
        QUESTION 'What was F Middleton''s batting Match Factor on 1 May 2026?'
        SQL 'SELECT DISTINCT b.player_name, m.match_date, fb.batting_match_factor FROM fact_batting AS fb JOIN batters AS b ON fb.player_id = b.player_id JOIN dim_match AS m ON fb.match_id = m.match_id WHERE b.player_name = ''F Middleton'' AND m.match_date = ''2026-05-01'''
    ),
    bowling_match_factor_for_bowler AS (
        QUESTION 'What was B Kellaway''s bowling Match Factor on 1 May 2026?'
        SQL 'SELECT DISTINCT bo.player_name, m.match_date, bw.bowling_match_factor FROM fact_bowling AS bw JOIN bowlers AS bo ON bw.player_id = bo.player_id JOIN dim_match AS m ON bw.match_id = m.match_id WHERE bo.player_name = ''B Kellaway'' AND m.match_date = ''2026-05-01'''
    ),
    partnerships_for_team_in_match AS (
        QUESTION 'What were Hampshire''s batting partnerships on 1 May 2026?'
        SQL 'SELECT t.team_name, fp.team_innings_number, fp.partnership_number, b1.player_name AS batter_1, b2.player_name AS batter_2, fp.partnership_runs, fp.how_ended FROM fact_partnership AS fp JOIN batting_teams AS t ON fp.team_id = t.team_id JOIN partnership_batter_1 AS b1 ON fp.batter_1_id = b1.player_id JOIN partnership_batter_2 AS b2 ON fp.batter_2_id = b2.player_id JOIN dim_match AS m ON fp.match_id = m.match_id WHERE t.team_name = ''Hampshire'' AND m.match_date = ''2026-05-01'' ORDER BY fp.team_innings_number, fp.partnership_number'
    ),
    fielding_stats_for_player AS (
        QUESTION 'How many catches and stumpings has F Middleton taken?'
        SQL 'SELECT f.player_name, SUM(CASE WHEN ff.dismissal_type = ''CAUGHT'' THEN 1 ELSE 0 END) AS catches, SUM(CASE WHEN ff.dismissal_type = ''STUMPED'' THEN 1 ELSE 0 END) AS stumpings FROM fact_fielding AS ff JOIN fielders AS f ON ff.fielder_id = f.player_id WHERE f.player_name = ''F Middleton'' GROUP BY f.player_name'
    ),
    best_all_rounders AS (
        QUESTION 'Who are the top 10 all-rounders, combining batting and bowling Match Factor, among players who batted and bowled in at least 5 matches?'
        SQL 'SELECT sp.player_name, ((SUM(fpms.mf_bat_own_runs) + SUM(fpms.mf_bat_peer_runs) / NULLIF(SUM(fpms.mf_bat_peer_dismissals), 0)) / (SUM(fpms.mf_bat_own_dismissals) + 1)) / NULLIF(SUM(fpms.mf_bat_peer_runs) / NULLIF(SUM(fpms.mf_bat_peer_dismissals), 0), 0) AS pooled_batting_match_factor, CASE WHEN SUM(fpms.mf_bowl_own_wickets) > 0 THEN (SUM(fpms.mf_bowl_peer_runs_conceded) / NULLIF(SUM(fpms.mf_bowl_peer_wickets), 0)) / NULLIF((SUM(fpms.mf_bowl_own_runs_conceded) + SUM(fpms.mf_bowl_peer_runs_conceded) / NULLIF(SUM(fpms.mf_bowl_peer_wickets), 0)) / (SUM(fpms.mf_bowl_own_wickets) + 1), 0) END AS pooled_bowling_match_factor, (((SUM(fpms.mf_bat_own_runs) + SUM(fpms.mf_bat_peer_runs) / NULLIF(SUM(fpms.mf_bat_peer_dismissals), 0)) / (SUM(fpms.mf_bat_own_dismissals) + 1)) / NULLIF(SUM(fpms.mf_bat_peer_runs) / NULLIF(SUM(fpms.mf_bat_peer_dismissals), 0), 0)) + (CASE WHEN SUM(fpms.mf_bowl_own_wickets) > 0 THEN (SUM(fpms.mf_bowl_peer_runs_conceded) / NULLIF(SUM(fpms.mf_bowl_peer_wickets), 0)) / NULLIF((SUM(fpms.mf_bowl_own_runs_conceded) + SUM(fpms.mf_bowl_peer_runs_conceded) / NULLIF(SUM(fpms.mf_bowl_peer_wickets), 0)) / (SUM(fpms.mf_bowl_own_wickets) + 1), 0) END) AS all_rounder_composite FROM fact_player_match_summary AS fpms JOIN summary_players AS sp ON fpms.player_id = sp.player_id GROUP BY sp.player_name HAVING SUM(CASE WHEN fpms.mf_bat_own_runs IS NOT NULL AND fpms.mf_bowl_own_wickets IS NOT NULL THEN 1 ELSE 0 END) >= 5 ORDER BY all_rounder_composite DESC NULLS LAST LIMIT 10'
    ),
    team_match_summary_totals AS (
        QUESTION 'What were Hampshire''s total runs, wickets lost, and result against Glamorgan on 1 May 2026?'
        SQL 'SELECT st.team_name, m.match_date, ftms.total_runs, ftms.total_wickets_lost, ftms.total_runs_conceded, ftms.total_wickets_taken, ftms.won FROM fact_team_match_summary AS ftms JOIN summary_teams AS st ON ftms.team_id = st.team_id JOIN dim_match AS m ON ftms.match_id = m.match_id WHERE st.team_name = ''Hampshire'' AND m.match_date = ''2026-05-01'''
    )
)
