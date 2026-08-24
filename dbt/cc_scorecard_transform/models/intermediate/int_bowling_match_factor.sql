-- Grain: one row per player per MATCH. Same match-level aggregation
-- rationale as int_batting_match_factor. Peer group = all other bowlers
-- in the match — discipline segmentation (pace/spin) deliberately
-- deferred, see docs/dbt-modeling-plan.md.
--
-- Ratio orientation is inverted vs. batting (peer average over the
-- numerator, own average as denominator) so "higher is better" holds for
-- both metrics — a lower bowling average is better, so this flips it.
--
-- NULL (not zero) when the player took zero wickets in the match — their
-- own bowling average is undefined, not zero, per the design decision.

with bowling_rows as (

    select
        source_file_name,
        player_name,
        runs_conceded,
        wickets
    from {{ ref('int_bowling_rows') }}

),

player_own_totals as (

    select
        source_file_name,
        player_name,
        sum(runs_conceded) as own_runs_conceded,
        sum(wickets) as own_wickets
    from bowling_rows
    group by 1, 2

),

match_totals as (

    select
        source_file_name,
        sum(runs_conceded) as match_runs_conceded,
        sum(wickets) as match_wickets
    from bowling_rows
    group by 1

)

select
    p.source_file_name,
    p.player_name,
    p.own_runs_conceded,
    p.own_wickets,
    case
        when p.own_wickets > 0 then p.own_runs_conceded::float / p.own_wickets
    end as own_bowling_average,
    (m.match_runs_conceded - p.own_runs_conceded) as peer_runs_conceded,
    (m.match_wickets - p.own_wickets) as peer_wickets,
    case
        when (m.match_wickets - p.own_wickets) > 0
            then (m.match_runs_conceded - p.own_runs_conceded)::float / (m.match_wickets - p.own_wickets)
    end as peer_bowling_average,
    case
        when p.own_wickets > 0 and (m.match_wickets - p.own_wickets) > 0
            then
                ((m.match_runs_conceded - p.own_runs_conceded)::float / (m.match_wickets - p.own_wickets))
                / (p.own_runs_conceded::float / p.own_wickets)
    end as bowling_match_factor
from player_own_totals p
join match_totals m on p.source_file_name = m.source_file_name
