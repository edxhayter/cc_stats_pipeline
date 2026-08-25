-- cumulative_score must never decrease within an innings, and wicket_number
-- must be sequential (1,2,3...). Equal consecutive scores ARE legitimate
-- (two wickets falling for the same team total) and must not be flagged —
-- confirmed 317 such cases exist in real data, all correct.

select
    source_file_name,
    team,
    team_innings_number,
    wicket_number,
    cumulative_score,
    lag(cumulative_score) over (
        partition by source_file_name, team, team_innings_number order by wicket_number
    ) as prev_score,
    lag(wicket_number) over (
        partition by source_file_name, team, team_innings_number order by wicket_number
    ) as prev_wicket_number
from {{ ref('int_fow_rows') }}
qualify
    (prev_score is not null and cumulative_score < prev_score)
    or (prev_wicket_number is not null and wicket_number != prev_wicket_number + 1)
