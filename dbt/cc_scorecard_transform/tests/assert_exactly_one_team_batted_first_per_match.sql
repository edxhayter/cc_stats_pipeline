select match_id, count(*) as batted_first_count
from {{ ref('fact_team_match_summary') }}
where batted_first
group by match_id
having count(*) != 1
