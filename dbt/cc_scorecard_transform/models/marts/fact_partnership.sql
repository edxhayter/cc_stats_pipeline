-- Grain: partnership x team-innings x match. See int_partnerships for how
-- the pairing/how_ended logic works (self-join on adjacent batting
-- positions, not a full simulation) and its one known limitation
-- (the retired-hurt match produces a nonsensical self-partnership row).

select
    m.match_id,
    t.team_id,
    p.team_innings_number,
    p.match_innings_sequence,
    p.partnership_number,
    b1.player_id as batter_1_id,
    b2.player_id as batter_2_id,
    p.how_ended,
    p.partnership_runs
from {{ ref('int_partnerships') }} p
join {{ ref('dim_match') }} m on p.source_file_name = m.source_file_name
join {{ ref('dim_team') }} t on p.team = t.team_name
join {{ ref('dim_player') }} b1 on p.batter_1_name = b1.player_name
join {{ ref('dim_player') }} b2 on p.batter_2_name = b2.player_name
