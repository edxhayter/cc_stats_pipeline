-- One row per bowler x team-innings x match.
--
-- Confirmed fixed-width name column (16 chars, same as batting); the
-- numeric tail (O, M/D, R, W, Econ) parses cleanly for all 2570 real
-- bowling_data rows via whitespace-collapse + split, no dismissal-text
-- complexity to worry about here unlike batting.
--
-- A bowling block's block_id is always exactly its paired batting block's
-- block_id + 1 (confirmed against stg_blocks output — exactly one marker
-- line separates them, every time). team_innings_number/match_innings_sequence
-- describe that shared phase of the match; bowling_team is the opponent of
-- whoever was batting in the paired block, not int_innings_totals.team itself.

with bowling_rows as (

    select
        source_file_name,
        block_id,
        source_file_row_number,
        trim(substr(raw_line, 1, 16)) as player_name,
        trim(regexp_replace(substr(raw_line, 17), '\\s+', ' ')) as stats_collapsed
    from {{ ref('stg_row_classification') }}
    where row_type = 'bowling_data'

),

with_position as (

    select
        *,
        row_number() over (
            partition by source_file_name, block_id order by source_file_row_number
        ) as bowling_position,
        split_part(stats_collapsed, ' ', 1) as overs_raw,
        split_part(stats_collapsed, ' ', 2) as maiden_or_dot_raw,
        split_part(stats_collapsed, ' ', 3) as runs_raw,
        split_part(stats_collapsed, ' ', 4) as wickets_raw,
        split_part(stats_collapsed, ' ', 5) as econ_raw
    from bowling_rows

),

innings_context as (

    select
        i.source_file_name,
        i.block_id + 1 as bowling_block_id,
        i.team_innings_number,
        i.match_innings_sequence,
        case
            when i.team = mh.home_team then mh.away_team
            else mh.home_team
        end as bowling_team,
        mh.match_format
    from {{ ref('int_innings_totals') }} i
    join {{ ref('int_match_header') }} mh on i.source_file_name = mh.source_file_name

)

select
    p.source_file_name,
    ic.bowling_team,
    ic.team_innings_number,
    ic.match_innings_sequence,
    p.bowling_position,
    p.player_name,
    try_to_number(p.overs_raw) as overs,
    case
        when ic.match_format in ('T20', 'T20I') then try_to_number(p.maiden_or_dot_raw)
    end as dots_bowled,
    case
        when ic.match_format not in ('T20', 'T20I') then try_to_number(p.maiden_or_dot_raw)
    end as maidens,
    try_to_number(p.runs_raw) as runs_conceded,
    try_to_number(p.wickets_raw) as wickets,
    try_to_number(p.econ_raw) as economy
from with_position p
join innings_context ic
    on p.source_file_name = ic.source_file_name and p.block_id = ic.bowling_block_id
