-- Still 1:1 grain with the source. Classifies each line's role within its
-- block, so the intermediate layer can filter directly on row_type instead
-- of re-deriving these patterns. NULL for marker lines, matching how
-- block_type is NULL for them in stg_blocks.
--
-- "Fall of Wickets:" and its data lines are row_types WITHIN a `bowling`
-- block (see stg_blocks — FOW isn't its own marker-delimited block), and
-- extras/total lines are within a `batting` block, both confirmed against
-- real sample files rather than assumed.

with base as (

    select
        *,
        trim(raw_line) as trimmed_line
    from {{ ref('stg_blocks') }}

)

select
    raw_line,
    source_file_name,
    source_file_row_number,
    loaded_at,
    is_marker_line,
    block_id,
    block_type,
    case
        when is_marker_line then null
        when trimmed_line = '' then 'blank'
        when regexp_like(trimmed_line, '^-+$') then 'divider'
        when block_type = 'match_header' then 'match_header_data'
        when block_type = 'result' then 'result_data'
        when block_type = 'batting'
            and regexp_like(raw_line, '.* - (1st|2nd) Innings\\s+R\\s+B\\s+4s\\s+6s\\s*$')
            then 'batting_header'
        when block_type = 'batting' and trimmed_line ilike 'Extras:%' then 'extras'
        when block_type = 'batting' and trimmed_line ilike 'TOTAL:%' then 'total'
        when block_type = 'batting' then 'batting_data'
        when block_type = 'bowling'
            and regexp_like(trimmed_line, '^O\\s+(M|D)\\s+R\\s+W\\s+Econ$')
            then 'bowling_header'
        when block_type = 'bowling' and trimmed_line ilike 'Fall of Wickets:%' then 'fow_header'
        when block_type = 'bowling' and regexp_like(trimmed_line, '^([0-9]+-[0-9]+\\s*)+$') then 'fow_data'
        when block_type = 'bowling' then 'bowling_data'
        else null
    end as row_type
from base
