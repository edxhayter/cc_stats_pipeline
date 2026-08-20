-- Grain is really one row per batting STINT, not strictly one per batter
-- x team-innings x match — a retired-hurt batter who later returns is
-- listed twice in the same innings (confirmed in 1 of 173 real files:
-- Sri Lanka's K Mendis, both innings, "25 Jun 2026-WI v SL (1st TST).txt").
-- batting_position disambiguates the two rows; (player, team_innings,
-- match) alone is not a unique key. Marts layer needs to account for this
-- rather than assume batter uniqueness per innings.
--
-- Confirmed fixed-width format (checked LENGTH distribution across all
-- 5544 real batting_data rows, only two values exist): name = columns
-- 1-16, dismissal detail = columns 17-42, stats = columns 43+. A did-not-bat
-- row is exactly 16 chars (name only, nothing else) — no separate flag
-- needed, LENGTH is a reliable discriminator on real data.
--
-- Deliberately NOT parsed by searching for dismissal keywords anywhere in
-- the line — surnames ending in "st" (Hurst, Gilchrist, Guest, Northeast)
-- false-positive-match a loose "st " (stumped) search well before the real
-- dismissal text starts. Fixed-column extraction avoids this entirely.

with batting_rows as (

    select
        source_file_name,
        block_id,
        source_file_row_number,
        length(raw_line) = 16 as did_not_bat,
        trim(substr(raw_line, 1, 16)) as player_name,
        case
            when length(raw_line) = 16 then null
            else trim(substr(raw_line, 17, 26))
        end as dismissal_detail,
        case
            when length(raw_line) = 16 then null
            else trim(regexp_replace(substr(raw_line, 43), '\\s+', ' '))
        end as stats_collapsed
    from {{ ref('stg_row_classification') }}
    where row_type = 'batting_data'

),

with_position as (

    select
        *,
        row_number() over (
            partition by source_file_name, block_id order by source_file_row_number
        ) as batting_position
    from batting_rows

),

parsed as (

    select
        source_file_name,
        block_id,
        batting_position,
        player_name,
        did_not_bat,
        dismissal_detail,
        case
            when did_not_bat then 'DID_NOT_BAT'
            when dismissal_detail ilike 'not out%' then 'NOT_OUT'
            when dismissal_detail ilike 'rtrd%' or dismissal_detail ilike '%retired%' then 'RETIRED_HURT'
            when dismissal_detail ilike 'c %' then 'CAUGHT'
            when dismissal_detail ilike 'lbw%' then 'LBW'
            when dismissal_detail ilike 'run out%' then 'RUN_OUT'
            when dismissal_detail ilike 'st %' then 'STUMPED'
            when dismissal_detail ilike 'b %' then 'BOWLED'
            else null
        end as dismissal_type,
        split_part(stats_collapsed, ' ', 1) as runs_raw,
        split_part(stats_collapsed, ' ', 2) as balls_raw,
        split_part(stats_collapsed, ' ', 3) as fours_raw,
        split_part(stats_collapsed, ' ', 4) as sixes_raw
    from with_position

)

select
    i.source_file_name,
    i.team as batting_team,
    i.team_innings_number,
    i.match_innings_sequence,
    p.batting_position,
    p.player_name,
    p.did_not_bat,
    p.dismissal_type,
    p.dismissal_detail,
    -- '-' means zero in this format (a genuine boundary count of zero),
    -- not a missing value — must not be left as NULL.
    case when p.runs_raw = '-' then 0 else try_to_number(p.runs_raw) end as runs,
    case when p.balls_raw = '-' then 0 else try_to_number(p.balls_raw) end as balls_faced,
    case when p.fours_raw = '-' then 0 else try_to_number(p.fours_raw) end as fours,
    case when p.sixes_raw = '-' then 0 else try_to_number(p.sixes_raw) end as sixes
from parsed p
join {{ ref('int_innings_totals') }} i
    on p.source_file_name = i.source_file_name and p.block_id = i.block_id
