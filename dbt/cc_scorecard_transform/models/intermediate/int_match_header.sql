-- Grain change from here on: one row per match, not per line.
-- The match_header block is always exactly 2 lines (validated against all
-- 173 files): "{Team} v {Team}" then "{Competition} - {Date}".

with header_lines as (

    select
        source_file_name,
        row_number() over (
            partition by source_file_name order by source_file_row_number
        ) as line_number,
        trim(raw_line) as content
    from {{ ref('stg_row_classification') }}
    where row_type = 'match_header_data'

),

pivoted as (

    select
        source_file_name,
        max(case when line_number = 1 then content end) as team_line,
        max(case when line_number = 2 then content end) as competition_date_line
    from header_lines
    group by source_file_name

),

with_format as (

    select
        source_file_name,
        trim(split_part(team_line, ' v ', 1)) as home_team,
        trim(split_part(team_line, ' v ', 2)) as away_team,
        competition_date_line,
        regexp_substr(competition_date_line, '[0-9]{1,2} [A-Za-z]+ [0-9]{4}$') as match_date_string,
        trim(
            regexp_replace(competition_date_line, '\\s*-\\s*[0-9]{1,2} [A-Za-z]+ [0-9]{4}$', '')
        ) as competition_portion,
        case
            when competition_date_line ilike '%Test Match%' then 'TEST'
            when competition_date_line ilike '%One Day International%' then 'ODI'
            when competition_date_line ilike '%20 Over International%' then 'T20I'
            when competition_date_line ilike '%20 Over Trophy%' then 'T20'
            when competition_date_line ilike '%FC League%' then 'FC_LEAGUE'
            else 'UNKNOWN'
        end as match_format
    from pivoted

)

select
    source_file_name,
    home_team,
    away_team,
    to_date(match_date_string, 'DD Mon YYYY') as match_date,
    match_format,
    case match_format
        when 'FC_LEAGUE' then trim(split_part(competition_portion, ' - ', 1))
        when 'T20' then trim(split_part(competition_portion, ' - ', 1))
        when 'TEST' then 'Test Match'
        when 'ODI' then 'One Day International'
        when 'T20I' then '20 Over International'
        else null
    end as competition_name,
    case match_format
        when 'FC_LEAGUE' then trim(split_part(competition_portion, ' - ', 2))
        when 'T20' then trim(split_part(competition_portion, ' - ', 2))
        when 'TEST' then trim(regexp_replace(competition_portion, '\\s*Test Match\\s*', ' '))
        when 'ODI' then trim(regexp_replace(competition_portion, '\\s*One Day International\\s*', ' '))
        when 'T20I' then trim(regexp_replace(competition_portion, '\\s*20 Over International\\s*', ' '))
        else null
    end as competition_variant
from with_format
