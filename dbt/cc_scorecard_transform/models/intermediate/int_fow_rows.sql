-- One row per wicket x team-innings x match. Handles the line-wrap: a
-- single fow_data line holds multiple "N-M" tokens (wicket-cumulative_score
-- pairs), and an innings with >5 wickets wraps onto a second fow_data line
-- — both are exploded here via LATERAL FLATTEN into one row per wicket.
--
-- FOW rows live inside the bowling block (see stg_blocks — FOW trails the
-- bowling figures, same block), so joining back to int_innings_totals
-- (keyed by the batting block's block_id) needs block_id - 1. The team
-- here is the batting side (the team losing wickets), same as
-- int_innings_totals.team directly — no opposing-team logic needed,
-- unlike int_bowling_rows.

with fow_lines as (

    select
        source_file_name,
        block_id,
        trim(regexp_replace(raw_line, '\\s+', ' ')) as collapsed_line
    from {{ ref('stg_row_classification') }}
    where row_type = 'fow_data'

),

exploded as (

    select
        f.source_file_name,
        f.block_id,
        token.value::string as token
    from fow_lines f,
        lateral flatten(input => split(f.collapsed_line, ' ')) token
    where token.value::string != ''

),

parsed as (

    select
        source_file_name,
        block_id,
        try_to_number(split_part(token, '-', 1)) as wicket_number,
        try_to_number(split_part(token, '-', 2)) as cumulative_score
    from exploded

)

select
    p.source_file_name,
    i.team,
    i.team_innings_number,
    i.match_innings_sequence,
    p.wicket_number,
    p.cumulative_score
from parsed p
join {{ ref('int_innings_totals') }} i
    on p.source_file_name = i.source_file_name and i.block_id = p.block_id - 1
