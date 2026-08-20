-- One row per team-innings x match. team_innings_number comes straight off
-- the batting_header text ("Hampshire - 1st Innings" -> 1); match_innings_sequence
-- is the ordinal rank of batting blocks within the file (1-2 for limited
-- overs, 1-4 for FC/Test) — one batting block = one innings, so ranking
-- them in block order gives this directly, no separate derivation needed.

with batting_headers as (

    select
        source_file_name,
        block_id,
        trim(regexp_substr(raw_line, '^(.*) - (1st|2nd) Innings', 1, 1, 'e', 1)) as team,
        case
            when raw_line ilike '%1st Innings%' then 1
            when raw_line ilike '%2nd Innings%' then 2
        end as team_innings_number
    from {{ ref('stg_row_classification') }}
    where row_type = 'batting_header'

),

extras as (

    select
        source_file_name,
        block_id,
        try_to_number(regexp_substr(raw_line, '([0-9]+)\\s*$', 1, 1, 'e', 1)) as extras_total
    from {{ ref('stg_row_classification') }}
    where row_type = 'extras'

),

totals as (

    select
        source_file_name,
        block_id,
        regexp_substr(raw_line, 'TOTAL:\\s*\\(([^,]+),', 1, 1, 'e', 1) as total_detail,
        try_to_number(regexp_substr(raw_line, '([0-9.]+)\\s*overs', 1, 1, 'e', 1)) as overs_faced,
        try_to_number(regexp_substr(raw_line, '([0-9]+)\\s*$', 1, 1, 'e', 1)) as total_runs
    from {{ ref('stg_row_classification') }}
    where row_type = 'total'

)

select
    h.source_file_name,
    h.block_id,
    h.team,
    h.team_innings_number,
    dense_rank() over (
        partition by h.source_file_name order by h.block_id
    ) as match_innings_sequence,
    t.total_runs,
    case
        when t.total_detail ilike '%all out%' then 10
        else try_to_number(regexp_substr(t.total_detail, '([0-9]+)', 1, 1, 'e', 1))
    end as wickets_lost,
    t.overs_faced,
    e.extras_total
from batting_headers h
left join extras e
    on h.source_file_name = e.source_file_name and h.block_id = e.block_id
left join totals t
    on h.source_file_name = t.source_file_name and h.block_id = t.block_id
