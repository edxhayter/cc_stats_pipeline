select
    m.match_id,
    t.team_id,
    f.team_innings_number,
    f.match_innings_sequence,
    f.wicket_number,
    f.cumulative_score
from {{ ref('int_fow_rows') }} f
join {{ ref('dim_match') }} m on f.source_file_name = m.source_file_name
join {{ ref('dim_team') }} t on f.team = t.team_name
