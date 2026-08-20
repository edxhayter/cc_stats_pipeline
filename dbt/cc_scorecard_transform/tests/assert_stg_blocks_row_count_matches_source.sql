-- Staging must never drop or duplicate raw lines, only annotate them.
-- This test returns rows (fails) if stg_blocks' row count ever diverges
-- from stg_scorecard_lines' — per file, since a divergence could hide
-- inside an otherwise-matching total.

select
    s.source_file_name,
    count(distinct s.source_file_row_number) as source_lines,
    count(distinct b.source_file_row_number) as block_lines
from {{ ref('stg_scorecard_lines') }} s
left join {{ ref('stg_blocks') }} b
    on s.source_file_name = b.source_file_name
    and s.source_file_row_number = b.source_file_row_number
group by s.source_file_name
having count(distinct s.source_file_row_number) != count(distinct b.source_file_row_number)
