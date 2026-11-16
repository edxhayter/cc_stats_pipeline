-- Every innings' wicket stands, including any unbroken one, must add up to
-- the innings total: the stands are the total split at each fall of wicket.

with stands as (

    select source_file_name, match_innings_sequence, sum(partnership_runs) as stand_total
    from {{ ref('int_partnerships') }}
    group by 1, 2

)

select s.source_file_name, s.match_innings_sequence, s.stand_total, it.total_runs
from stands s
join {{ ref('int_innings_totals') }} it
    on s.source_file_name = it.source_file_name
    and s.match_innings_sequence = it.match_innings_sequence
where s.stand_total != it.total_runs
