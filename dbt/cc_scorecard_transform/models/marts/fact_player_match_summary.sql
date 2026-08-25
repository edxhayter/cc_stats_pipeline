-- Grain: one row per player per match — batting + bowling + fielding
-- combined, so single-entity questions don't need multi-fact joins.
-- Sourced from the existing facts (not int_ models) since this is a new
-- downstream mart with no circularity risk, unlike fact_batting/
-- fact_bowling's own Match Factor columns which had to source from
-- int_ models specifically to avoid a cycle.
--
-- Milestone counts (centuries, half-centuries, five-wicket hauls) are
-- per-INNINGS thresholds summed across a player's innings in the match —
-- e.g. two 60-run innings in a Test doesn't make a century, but a
-- player scoring 100+ in either individual innings does count once.
--
-- Count-style columns (dismissals, centuries, five_wicket_hauls, etc.)
-- are 0 when the player has activity in that discipline but didn't hit
-- the threshold. Raw sums (total_wickets, total_runs_conceded) are NULL
-- when the player has no rows in that discipline at all (e.g. a
-- specialist batter never bowled) — a natural LEFT JOIN miss, not an
-- explicit default, so "didn't bowl" stays distinguishable from "bowled
-- and conceded/took nothing".

with roster as (

    select match_id, player_id, team_id from {{ ref('fact_batting') }}
    union
    select match_id, player_id, team_id from {{ ref('fact_bowling') }}

),

batting_agg as (

    select
        match_id,
        player_id,
        sum(runs) as total_runs,
        sum(balls_faced) as total_balls_faced,
        sum(fours) as total_fours,
        sum(sixes) as total_sixes,
        sum(case when dismissal_type not in ('NOT_OUT', 'DID_NOT_BAT', 'RETIRED_HURT') then 1 else 0 end) as dismissals,
        sum(case when runs >= 100 then 1 else 0 end) as centuries,
        sum(case when runs >= 50 and runs < 100 then 1 else 0 end) as half_centuries,
        max(batting_match_factor) as batting_match_factor
    from {{ ref('fact_batting') }}
    group by 1, 2

),

bowling_agg as (

    select
        match_id,
        player_id,
        sum(overs) as total_overs_naive,
        sum(runs_conceded) as total_runs_conceded,
        sum(wickets) as total_wickets,
        sum(case when wickets >= 5 then 1 else 0 end) as five_wicket_hauls,
        max(bowling_match_factor) as bowling_match_factor
    from {{ ref('fact_bowling') }}
    group by 1, 2

),

fielding_agg as (

    select
        match_id,
        fielder_id as player_id,
        sum(case when dismissal_type = 'CAUGHT' then 1 else 0 end) as catches,
        sum(case when dismissal_type = 'STUMPED' then 1 else 0 end) as stumpings
    from {{ ref('fact_fielding') }}
    where fielder_id is not null
    group by 1, 2

)

select
    r.match_id,
    r.player_id,
    r.team_id,
    case
        when r.team_id = m.home_team_id then m.away_team_id
        else m.home_team_id
    end as opposition_team_id,
    ba.total_runs,
    ba.total_balls_faced,
    ba.total_fours,
    ba.total_sixes,
    coalesce(ba.dismissals, 0) as dismissals,
    coalesce(ba.centuries, 0) as centuries,
    coalesce(ba.half_centuries, 0) as half_centuries,
    ba.batting_match_factor,
    bw.total_overs_naive,
    bw.total_runs_conceded,
    bw.total_wickets,
    coalesce(bw.five_wicket_hauls, 0) as five_wicket_hauls,
    bw.bowling_match_factor,
    coalesce(fi.catches, 0) as catches,
    coalesce(fi.stumpings, 0) as stumpings,
    (r.player_id = m.man_of_the_match_id) as is_man_of_the_match
from roster r
join {{ ref('dim_match') }} m on r.match_id = m.match_id
left join batting_agg ba on r.match_id = ba.match_id and r.player_id = ba.player_id
left join bowling_agg bw on r.match_id = bw.match_id and r.player_id = bw.player_id
left join fielding_agg fi on r.match_id = fi.match_id and r.player_id = fi.player_id
