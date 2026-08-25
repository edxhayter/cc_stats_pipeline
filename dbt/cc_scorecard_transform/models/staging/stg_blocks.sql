-- Still 1:1 grain with the source — every row here is annotation only,
-- no reshaping. Block boundaries are lines of `*` characters; a running
-- sum of marker-line occurrences per file gives every real content line
-- between two marker-runs the same block_id (classic gaps-and-islands).
--
-- Structural note (confirmed against real sample files, not assumed):
-- "Fall of Wickets:" is NOT its own marker-delimited block — it trails
-- directly after the bowling figures within the same block, no marker
-- line separates them. So block_type only has four values; row-level
-- distinction between bowling rows and FOW rows happens one layer up,
-- in stg_row_classification.

with lines as (

    select
        raw_line,
        source_file_name,
        source_file_row_number,
        loaded_at,
        regexp_like(trim(raw_line), '^\\*+$') as is_marker_line
    from {{ ref('stg_scorecard_lines') }}

),

with_block_id as (

    select
        *,
        sum(case when is_marker_line then 1 else 0 end) over (
            partition by source_file_name
            order by source_file_row_number
            rows between unbounded preceding and current row
        ) as block_id
    from lines

),

content_bounds as (

    select
        *,
        min(case when not is_marker_line then block_id end) over (
            partition by source_file_name
        ) as min_content_block_id,
        max(case when not is_marker_line then block_id end) over (
            partition by source_file_name
        ) as max_content_block_id,
        max(
            case
                when regexp_like(raw_line, '.* - (1st|2nd) Innings\\s+R\\s+B\\s+4s\\s+6s\\s*$')
                    then 1
                else 0
            end
        ) over (partition by source_file_name, block_id) as is_batting_block,
        max(
            case
                when regexp_like(trim(raw_line), '^O\\s+(M|D)\\s+R\\s+W\\s+Econ$')
                    then 1
                else 0
            end
        ) over (partition by source_file_name, block_id) as is_bowling_block
    from with_block_id

)

select
    raw_line,
    source_file_name,
    source_file_row_number,
    loaded_at,
    is_marker_line,
    block_id,
    case
        when is_marker_line then null
        when block_id = min_content_block_id then 'match_header'
        when block_id = max_content_block_id then 'result'
        when is_batting_block = 1 then 'batting'
        when is_bowling_block = 1 then 'bowling'
        else 'unknown'
    end as block_type
from content_bounds
