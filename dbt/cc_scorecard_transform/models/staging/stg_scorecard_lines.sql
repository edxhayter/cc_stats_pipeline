-- 1:1 grain with the source: one row per raw line, no reshaping.
select
    raw_line,
    source_file_name,
    source_file_row_number,
    loaded_at
from {{ source('cricket_scorecards_raw', 'scorecard_lines') }}
