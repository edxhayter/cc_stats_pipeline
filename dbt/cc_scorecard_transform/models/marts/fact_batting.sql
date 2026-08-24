-- Grain: batting stint x team-innings x match (see int_batting_rows —
-- not strictly player x team-innings x match, a retired-hurt batter who
-- returns is listed twice). batting_match_factor is added in a later
-- step, not yet present here.

select
    m.match_id,
    p.player_id,
    t.team_id,
    case
        when t.team_id = m.home_team_id then m.away_team_id
        else m.home_team_id
    end as opposition_team_id,
    b.team_innings_number,
    b.match_innings_sequence,
    b.batting_position,
    b.dismissal_type,
    b.dismissal_detail,
    b.did_not_bat,
    b.runs,
    b.balls_faced,
    b.fours,
    b.sixes,
    case
        when b.balls_faced > 0 then round(b.runs / b.balls_faced * 100, 2)
    end as strike_rate,
    case
        when it.total_runs > 0 then round(b.runs / it.total_runs * 100, 2)
    end as pct_of_team_innings_runs
from {{ ref('int_batting_rows') }} b
join {{ ref('dim_match') }} m on b.source_file_name = m.source_file_name
join {{ ref('dim_player') }} p on b.player_name = p.player_name
join {{ ref('dim_team') }} t on b.batting_team = t.team_name
left join {{ ref('int_innings_totals') }} it
    on b.source_file_name = it.source_file_name
    and b.batting_team = it.team
    and b.team_innings_number = it.team_innings_number
