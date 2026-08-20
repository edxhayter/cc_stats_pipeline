-- Same reconciliation as assert_stg_blocks_row_count_matches_source, one
-- layer further up the staging chain.

select
    s.source_file_name,
    count(distinct s.source_file_row_number) as source_lines,
    count(distinct r.source_file_row_number) as classified_lines
from {{ ref('stg_scorecard_lines') }} s
left join {{ ref('stg_row_classification') }} r
    on s.source_file_name = r.source_file_name
    and s.source_file_row_number = r.source_file_row_number
group by s.source_file_name
having count(distinct s.source_file_row_number) != count(distinct r.source_file_row_number)
