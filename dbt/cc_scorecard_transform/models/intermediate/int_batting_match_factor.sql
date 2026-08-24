-- Grain: one row per player per MATCH (not per innings) — the definition
-- explicitly compares a player's batting "in this match" as a whole, so a
-- player with two innings (Test/FC) gets their runs/dismissals summed
-- across both before the ratio is computed. Built from int_batting_rows
-- directly (not fact_batting) to avoid a circular dependency — fact_batting
-- joins this model's output back in by (source_file_name, player_name).
--
-- Peer group = top-6 batters from BOTH teams, across all innings in the
-- match — deliberately match-wide, not team-scoped, since the point is
-- normalizing for conditions (pitch, weather) shared by everyone who
-- played that specific match, not comparing within one side.
--
-- Edge case (see docs/dbt-modeling-plan.md): a player never dismissed in
-- the match uses total runs as the batting-average stand-in, per the
-- decision made when this metric was designed.

with top6_batting as (

    select
        source_file_name,
        player_name,
        runs,
        case
            when dismissal_type not in ('NOT_OUT', 'DID_NOT_BAT', 'RETIRED_HURT') then 1
            else 0
        end as is_dismissal
    from {{ ref('int_batting_rows') }}
    where batting_position <= 6
        and not did_not_bat

),

player_own_totals as (

    select
        source_file_name,
        player_name,
        sum(runs) as own_runs,
        sum(is_dismissal) as own_dismissals
    from top6_batting
    group by 1, 2

),

match_totals as (

    select
        source_file_name,
        sum(runs) as match_top6_runs,
        sum(is_dismissal) as match_top6_dismissals
    from top6_batting
    group by 1

)

select
    p.source_file_name,
    p.player_name,
    p.own_runs,
    p.own_dismissals,
    case
        when p.own_dismissals > 0 then p.own_runs::float / p.own_dismissals
        else p.own_runs
    end as own_batting_average,
    (m.match_top6_runs - p.own_runs) as peer_runs,
    (m.match_top6_dismissals - p.own_dismissals) as peer_dismissals,
    case
        when (m.match_top6_dismissals - p.own_dismissals) > 0
            then (m.match_top6_runs - p.own_runs)::float / (m.match_top6_dismissals - p.own_dismissals)
    end as peer_batting_average,
    case
        when (m.match_top6_dismissals - p.own_dismissals) > 0
            then
                (case when p.own_dismissals > 0 then p.own_runs::float / p.own_dismissals else p.own_runs end)
                / ((m.match_top6_runs - p.own_runs)::float / (m.match_top6_dismissals - p.own_dismissals))
    end as batting_match_factor
from player_own_totals p
join match_totals m on p.source_file_name = m.source_file_name
