-- Grain: one row per team per match. batted_first is derived from
-- whichever team's innings has match_innings_sequence = 1 — always
-- exactly one team per match, regardless of format.

with batted_first as (

    select source_file_name, team as team_batted_first_name
    from {{ ref('int_innings_totals') }}
    where match_innings_sequence = 1

),

batting_agg as (

    select
        source_file_name,
        team,
        sum(total_runs) as total_runs,
        sum(wickets_lost) as total_wickets_lost,
        sum(overs_faced) as total_overs_faced_naive
    from {{ ref('int_innings_totals') }}
    group by 1, 2

),

bowling_agg as (

    select
        source_file_name,
        bowling_team as team,
        sum(runs_conceded) as total_runs_conceded,
        sum(wickets) as total_wickets_taken
    from {{ ref('int_bowling_rows') }}
    group by 1, 2

),

teams as (

    select match_id, team_id from {{ ref('fact_batting') }}
    union
    select match_id, team_id from {{ ref('fact_bowling') }}

)

select
    t.match_id,
    t.team_id,
    case
        when t.team_id = m.home_team_id then m.away_team_id
        else m.home_team_id
    end as opposition_team_id,
    ba.total_runs,
    ba.total_wickets_lost,
    ba.total_overs_faced_naive,
    bw.total_runs_conceded,
    bw.total_wickets_taken,
    (bf.team_batted_first_name is not null) as batted_first,
    (t.team_id = m.winning_team_id) as won,
    m.result_type,
    m.result_margin_type,
    m.result_margin_value
from teams t
join {{ ref('dim_match') }} m on t.match_id = m.match_id
join {{ ref('dim_team') }} dt on t.team_id = dt.team_id
left join batting_agg ba on m.source_file_name = ba.source_file_name and dt.team_name = ba.team
left join bowling_agg bw on m.source_file_name = bw.source_file_name and dt.team_name = bw.team
left join batted_first bf on m.source_file_name = bf.source_file_name and dt.team_name = bf.team_batted_first_name
