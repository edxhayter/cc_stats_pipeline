with all_teams as (

    select home_team as team_name from {{ ref('int_match_header') }}
    union
    select away_team as team_name from {{ ref('int_match_header') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['team_name']) }} as team_id,
    team_name
from all_teams
