-- Grain: bowler x team-innings x match. pct_of_team_innings_wickets needs
-- the BATTING side's wickets_lost (the opposition of the bowling team),
-- not the bowling team's own int_innings_totals row — hence the
-- it.team != bw.bowling_team join condition below.

select
    m.match_id,
    p.player_id,
    t.team_id,
    case
        when t.team_id = m.home_team_id then m.away_team_id
        else m.home_team_id
    end as opposition_team_id,
    bw.team_innings_number,
    bw.match_innings_sequence,
    bw.overs,
    bw.maidens,
    bw.dots_bowled,
    bw.runs_conceded,
    bw.wickets,
    bw.economy,
    case
        when it.wickets_lost > 0 then round(bw.wickets / it.wickets_lost * 100, 2)
    end as pct_of_team_innings_wickets
from {{ ref('int_bowling_rows') }} bw
join {{ ref('dim_match') }} m on bw.source_file_name = m.source_file_name
join {{ ref('dim_player') }} p on bw.player_name = p.player_name
join {{ ref('dim_team') }} t on bw.bowling_team = t.team_name
left join {{ ref('int_innings_totals') }} it
    on bw.source_file_name = it.source_file_name
    and bw.team_innings_number = it.team_innings_number
    and it.team != bw.bowling_team
