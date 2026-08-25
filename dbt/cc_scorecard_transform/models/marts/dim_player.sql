-- Natural key is player name alone — no better disambiguator exists given
-- initials-only names (e.g. "N Gubbins"). Known limitation: no guarantee
-- of uniqueness across teams/countries if two different real players ever
-- share an abbreviated name. See docs/dbt-modeling-plan.md Open Items.

with all_players as (

    select player_name from {{ ref('int_batting_rows') }}
    union
    select player_name from {{ ref('int_bowling_rows') }}
    union
    select man_of_the_match as player_name
    from {{ ref('int_result') }}
    where man_of_the_match is not null

)

select
    {{ dbt_utils.generate_surrogate_key(['player_name']) }} as player_id,
    player_name
from all_players
