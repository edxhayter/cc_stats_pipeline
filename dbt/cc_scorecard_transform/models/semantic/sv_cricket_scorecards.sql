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
-- all_rounder_composite is AVG(batting_match_factor) + AVG(bowling_match_factor)
-- — a simple sum since both factors are already peer-normalized to 1.0 =
-- average, so >2.0 reads as "better than average at both disciplines
-- combined." No canonical formula was specified anywhere upstream; this is
-- a first cut, easy to revise.

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
    fact_player_match_summary.avg_batting_match_factor AS AVG(fact_player_match_summary.batting_match_factor),
    fact_player_match_summary.batting_match_factor_stddev AS STDDEV(fact_player_match_summary.batting_match_factor),
    fact_player_match_summary.avg_bowling_match_factor AS AVG(fact_player_match_summary.bowling_match_factor),
    fact_player_match_summary.bowling_match_factor_stddev AS STDDEV(fact_player_match_summary.bowling_match_factor),
    fact_player_match_summary.all_rounder_composite AS
        AVG(fact_player_match_summary.batting_match_factor) + AVG(fact_player_match_summary.bowling_match_factor),

    fact_team_match_summary.matches_played AS COUNT(fact_team_match_summary.match_id),
    fact_team_match_summary.wins AS SUM(CASE WHEN fact_team_match_summary.won THEN 1 ELSE 0 END),
    fact_team_match_summary.sum_total_runs AS SUM(fact_team_match_summary.total_runs),
    fact_team_match_summary.sum_total_wickets_taken AS SUM(fact_team_match_summary.total_wickets_taken)
)

-- A recent CREATE SEMANTIC VIEW addition (not in the syntax reference at
-- the time the rest of this model was first written) — curated
-- question+SQL pairs that improve Cortex Analyst's accuracy on the
-- question shapes users actually ask. SQL is plain SQL against the
-- physical mart tables (what Cortex Analyst itself generates under the
-- hood), not the SEMANTIC_VIEW(...) wrapper syntax used for manual
-- testing elsewhere in this project.
AI_VERIFIED_QUERIES (
    batting_average_for_player AS (
        QUESTION 'What is a specific player''s batting average?'
        SQL 'SELECT p.player_name, SUM(fb.runs) AS total_runs, SUM(CASE WHEN fb.dismissal_type NOT IN (''NOT_OUT'', ''DID_NOT_BAT'', ''RETIRED_HURT'') THEN 1 ELSE 0 END) AS dismissals, SUM(fb.runs) / NULLIF(SUM(CASE WHEN fb.dismissal_type NOT IN (''NOT_OUT'', ''DID_NOT_BAT'', ''RETIRED_HURT'') THEN 1 ELSE 0 END), 0) AS batting_average FROM {{ ref('fact_batting') }} fb JOIN {{ ref('dim_player') }} p ON fb.player_id = p.player_id WHERE p.player_name = ''N Gubbins'' GROUP BY p.player_name'
    ),
    wickets_and_economy_for_bowler AS (
        QUESTION 'How many wickets has a specific bowler taken, and what is their economy rate?'
        SQL 'SELECT p.player_name, SUM(bw.wickets) AS total_wickets, SUM(bw.runs_conceded) / NULLIF(SUM(bw.overs), 0) AS economy_rate FROM {{ ref('fact_bowling') }} bw JOIN {{ ref('dim_player') }} p ON bw.player_id = p.player_id WHERE p.player_name = ''B Kellaway'' GROUP BY p.player_name'
    ),
    match_result_and_motm AS (
        QUESTION 'Who won a specific match, by what margin, and who was man of the match?'
        SQL 'SELECT wt.team_name AS winning_team, m.result_margin_type, m.result_margin_value, mp.player_name AS man_of_the_match FROM {{ ref('dim_match') }} m JOIN {{ ref('dim_team') }} ht ON m.home_team_id = ht.team_id JOIN {{ ref('dim_team') }} at ON m.away_team_id = at.team_id LEFT JOIN {{ ref('dim_team') }} wt ON m.winning_team_id = wt.team_id LEFT JOIN {{ ref('dim_player') }} mp ON m.man_of_the_match_id = mp.player_id WHERE ht.team_name = ''Hampshire'' AND at.team_name = ''Glamorgan'' AND m.match_date = ''2026-05-01'''
    )
)
