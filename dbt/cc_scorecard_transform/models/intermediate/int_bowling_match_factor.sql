-- Grain: one row per player per MATCH. Same match-level aggregation
-- rationale as int_batting_match_factor. Peer group = all other bowlers
-- in the match — discipline segmentation (pace/spin) deliberately
-- deferred, see docs/dbt-modeling-plan.md.
--
-- Ratio orientation is inverted vs. batting (peer average over the
-- numerator, own average as denominator) so "higher is better" holds for
-- both metrics — a lower bowling average is better, so this flips it.
--
-- The player's own average is blended with one extra wicket at the peer
-- average: (own runs + peer avg) / (own wickets + 1). A raw own average
-- breaks on wickets-for-no-runs spells (divide by zero) and turns one cheap
-- wicket into a 13+ outlier; the blend keeps both finite and ranked sensibly
-- (3-0 in an over rates ~4.0, the best spell in the 2026 season) while
-- barely moving bowlers with real workloads. See docs/dbt-modeling-plan.md.
--
-- NULL (not zero) when the player took zero wickets in the match, per the
-- original design decision, or when the peer pool has no wickets or runs.

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

),

peer_averages as (

    select
        p.source_file_name,
        p.player_name,
        p.own_runs_conceded,
        p.own_wickets,
        (m.match_runs_conceded - p.own_runs_conceded) as peer_runs_conceded,
        (m.match_wickets - p.own_wickets) as peer_wickets,
        case
            when (m.match_wickets - p.own_wickets) > 0
                then (m.match_runs_conceded - p.own_runs_conceded)::float / (m.match_wickets - p.own_wickets)
        end as peer_bowling_average
    from player_own_totals p
    join match_totals m on p.source_file_name = m.source_file_name

)

select
    source_file_name,
    player_name,
    own_runs_conceded,
    own_wickets,
    case
        when own_wickets > 0 then own_runs_conceded::float / own_wickets
    end as own_bowling_average,
    peer_runs_conceded,
    peer_wickets,
    peer_bowling_average,
    case
        when own_wickets > 0 and peer_bowling_average > 0
            then peer_bowling_average
                / ((own_runs_conceded + peer_bowling_average) / (own_wickets + 1))
    end as bowling_match_factor
from peer_averages
