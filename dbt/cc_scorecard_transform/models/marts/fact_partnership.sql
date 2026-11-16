-- Grain: wicket stand x team-innings x match — the runs added for each
-- wicket, with no batter names (see int_partnerships for why).

select
    m.match_id,
    t.team_id,
    p.team_innings_number,
    p.match_innings_sequence,
    p.partnership_number,
    p.partnership_runs,
    p.is_unbroken
from {{ ref('int_partnerships') }} p
join {{ ref('dim_match') }} m on p.source_file_name = m.source_file_name
join {{ ref('dim_team') }} t on p.team = t.team_name
