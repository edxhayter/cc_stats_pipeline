-- One row per match. Result block is always exactly 2 lines: the result
-- line, then "Man of the match: {Player}".
--
-- DRAW/TIE/NO_RESULT patterns are defensive, not confirmed against a real
-- sample — none of the files checked so far show anything but a WIN. Flag
-- as UNKNOWN rather than guess if the real phrasing differs.

with result_lines as (

    select
        source_file_name,
        row_number() over (
            partition by source_file_name order by source_file_row_number
        ) as line_number,
        trim(raw_line) as content
    from {{ ref('stg_row_classification') }}
    where row_type = 'result_data'

),

pivoted as (

    select
        source_file_name,
        max(case when line_number = 1 then content end) as result_line,
        max(case when line_number = 2 then content end) as motm_line
    from result_lines
    group by source_file_name

)

select
    source_file_name,
    case
        when result_line ilike '%won by%' then 'WIN'
        when result_line ilike '%draw%' then 'DRAW'
        when result_line ilike '%tied%' then 'TIE'
        when result_line ilike '%no result%' then 'NO_RESULT'
        else 'UNKNOWN'
    end as result_type,
    case
        when result_line ilike '%won by%'
            then trim(regexp_substr(result_line, '^(.*) won by', 1, 1, 'e', 1))
        else null
    end as winning_team,
    case
        -- Innings victory: "won by an innings and 83 runs" — the margin
        -- that matters is the runs after "and", not "an" (which the plain
        -- 'won by ([0-9]+)' pattern would otherwise fail to match, or a
        -- naive check could misread as RUNS with no value). Confirmed
        -- against a real file (Sussex won by an innings and 83 runs).
        when result_line ilike '%won by an innings%'
            then try_to_number(regexp_substr(result_line, 'and ([0-9]+) run', 1, 1, 'e', 1))
        when result_line ilike '%won by%'
            then try_to_number(regexp_substr(result_line, 'won by ([0-9]+)', 1, 1, 'e', 1))
        else null
    end as result_margin_value,
    case
        when result_line ilike '%won by an innings%' then 'INNINGS'
        when result_line ilike '%won by%' and result_line ilike '%run%' then 'RUNS'
        when result_line ilike '%won by%' and result_line ilike '%wicket%' then 'WICKETS'
        else null
    end as result_margin_type,
    trim(regexp_replace(motm_line, '^Man of the match:\\s*', '')) as man_of_the_match
from pivoted
