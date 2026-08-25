-- Every wicket credited to a bowler (fact_bowling.wickets) must trace
-- back to a dismissal type that actually credits the bowler: CAUGHT,
-- STUMPED, BOWLED, or LBW. RUN_OUT deliberately doesn't count — cricket
-- convention doesn't credit the bowler's wicket tally for a run out.
-- This is exactly the kind of check that would have caught the
-- retired-hurt/fielding-resolution issues if they'd corrupted counts
-- rather than just producing NULLs/known-limitation rows.

with bowler_wickets as (

    select sum(wickets) as total from {{ ref('fact_bowling') }}

),

dismissal_derived_wickets as (

    select count(*) as total
    from {{ ref('int_batting_rows') }}
    where dismissal_type in ('CAUGHT', 'STUMPED', 'BOWLED', 'LBW')

)

select bw.total as bowler_wickets, dw.total as dismissal_derived_wickets
from bowler_wickets bw, dismissal_derived_wickets dw
where bw.total != dw.total
