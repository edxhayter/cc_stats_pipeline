-- Grain: one row per catch/stumping dismissal event. fielder_id/bowler_id
-- are NULL where int_fielding_dismissals couldn't resolve the surname to
-- exactly one roster player (ambiguous same-surname teammates, or the
-- fielder being the bowler themselves in a caught-and-bowled dismissal
-- where the bowler also didn't resolve — both are real, documented data
-- limitations, not join bugs).

select
    m.match_id,
    t.team_id,
    fd.team_innings_number,
    fd.match_innings_sequence,
    fielder.player_id as fielder_id,
    bowler.player_id as bowler_id,
    batter.player_id as batter_id,
    fd.dismissal_type,
    fd.caught_and_bowled
from {{ ref('int_fielding_dismissals') }} fd
join {{ ref('dim_match') }} m on fd.source_file_name = m.source_file_name
join {{ ref('dim_team') }} t on fd.team = t.team_name
join {{ ref('dim_player') }} batter on fd.batter_name = batter.player_name
left join {{ ref('dim_player') }} fielder on fd.fielder_name = fielder.player_name
left join {{ ref('dim_player') }} bowler on fd.bowler_name = bowler.player_name
