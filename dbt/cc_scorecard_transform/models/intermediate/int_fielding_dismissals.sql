-- One row per catch/stumping dismissal event. Run-outs are excluded —
-- confirmed this source format doesn't credit a fielder for them (just
-- "run out", nothing else).
--
-- Real discovery #1: fielder/bowler credit text uses SURNAME ONLY
-- ("c Westley b Harmer"), not the "Initial Surname" format used
-- everywhere else in this project (dim_player.player_name, e.g.
-- "N Gubbins"). Resolved back to full identity by matching the surname
-- against the fielding team's full match roster (anyone who batted or
-- bowled for that team anywhere in the match) — left NULL with a
-- match-count flag if the surname doesn't resolve to exactly one
-- roster player, rather than guessing on an ambiguous or missed match
-- (e.g. two same-surname teammates would be genuinely unresolvable from
-- this source data, not a bug to "fix").
--
-- Real discovery #2: "c & b {bowler}" is cricket's standard "caught and
-- bowled" notation — the fielder and bowler are the same person. Handled
-- explicitly rather than trying to resolve "&" against the roster (which
-- always fails, 62 real occurrences).
--
-- Real discovery #3: the same player's surname can be abbreviated
-- DIFFERENTLY depending on which fixed-width column it lands in — e.g.
-- "R Vasconcelos" in the main batting/bowling tables (fits in 16 chars)
-- but "V'oncelos" in the tighter 26-char dismissal-detail column. An
-- exact-suffix match against the roster's full surname misses this.
-- Fixed by matching on the fragment after the apostrophe when present
-- (matching the same abbreviation convention already seen in full names
-- like "T v' Gugten"), falling back to a normal space-anchored suffix
-- match otherwise.
--
-- match_innings_sequence (not team_innings_number) is used as part of the
-- row-identity key here since it's globally unique per file —
-- team_innings_number repeats between the two teams (both have a "1st
-- innings"), which would cause incorrect cross-team joins if used alone.

with dismissals as (

    select
        b.source_file_name,
        b.batting_team,
        b.match_innings_sequence,
        b.batting_position,
        b.player_name as batter_name,
        b.dismissal_type,
        case
            when b.dismissal_type = 'CAUGHT'
                then regexp_substr(b.dismissal_detail, '^c (.+) b (.+)$', 1, 1, 'e', 1)
            when b.dismissal_type = 'STUMPED'
                then regexp_substr(b.dismissal_detail, '^st (.+) b (.+)$', 1, 1, 'e', 1)
        end as fielder_surname,
        case
            when b.dismissal_type = 'CAUGHT'
                then regexp_substr(b.dismissal_detail, '^c (.+) b (.+)$', 1, 1, 'e', 2)
            when b.dismissal_type = 'STUMPED'
                then regexp_substr(b.dismissal_detail, '^st (.+) b (.+)$', 1, 1, 'e', 2)
        end as bowler_surname
    from {{ ref('int_batting_rows') }} b
    where b.dismissal_type in ('CAUGHT', 'STUMPED')

),

with_fielding_team as (

    select
        d.*,
        (d.fielder_surname = '&') as caught_and_bowled,
        -- surname fragment to match against the roster: after the
        -- apostrophe if present (abbreviation may differ by column
        -- width), else the full surname space-anchored to avoid partial
        -- word matches
        coalesce(
            nullif(split_part(d.fielder_surname, '''', 2), ''),
            ' ' || d.fielder_surname
        ) as fielder_match_fragment,
        coalesce(
            nullif(split_part(d.bowler_surname, '''', 2), ''),
            ' ' || d.bowler_surname
        ) as bowler_match_fragment,
        case
            when d.batting_team = mh.home_team then mh.away_team
            else mh.home_team
        end as fielding_team
    from dismissals d
    join {{ ref('int_match_header') }} mh on d.source_file_name = mh.source_file_name

),

roster as (

    select distinct source_file_name, batting_team as team, player_name
    from {{ ref('int_batting_rows') }}
    union
    select distinct source_file_name, bowling_team as team, player_name
    from {{ ref('int_bowling_rows') }}

),

fielder_matches as (

    select
        w.source_file_name,
        w.match_innings_sequence,
        w.batting_position,
        max(r.player_name) as fielder_candidate,
        count(distinct r.player_name) as fielder_match_count
    from with_fielding_team w
    left join roster r
        on w.source_file_name = r.source_file_name
        and w.fielding_team = r.team
        and r.player_name ilike '%' || w.fielder_match_fragment
        and not w.caught_and_bowled
    group by 1, 2, 3

),

bowler_matches as (

    select
        w.source_file_name,
        w.match_innings_sequence,
        w.batting_position,
        max(r.player_name) as bowler_candidate,
        count(distinct r.player_name) as bowler_match_count
    from with_fielding_team w
    left join roster r
        on w.source_file_name = r.source_file_name
        and w.fielding_team = r.team
        and r.player_name ilike '%' || w.bowler_match_fragment
    group by 1, 2, 3

),

fielding_team_innings_number as (

    -- the fielding team's own team_innings_number for this
    -- match_innings_sequence — already computed correctly in
    -- int_bowling_rows for exactly this (team, match_innings_sequence)
    -- pairing, so reuse it rather than re-deriving.
    select distinct source_file_name, match_innings_sequence, team_innings_number
    from {{ ref('int_bowling_rows') }}

)

select
    w.source_file_name,
    w.fielding_team as team,
    tin.team_innings_number,
    w.match_innings_sequence,
    w.batter_name,
    w.dismissal_type,
    w.caught_and_bowled,
    case
        when w.caught_and_bowled then
            case when bm.bowler_match_count = 1 then bm.bowler_candidate end
        when fm.fielder_match_count = 1 then fm.fielder_candidate
    end as fielder_name,
    case when w.caught_and_bowled then null else fm.fielder_match_count end as fielder_match_count,
    case when bm.bowler_match_count = 1 then bm.bowler_candidate end as bowler_name,
    bm.bowler_match_count
from with_fielding_team w
join fielder_matches fm
    on w.source_file_name = fm.source_file_name
    and w.match_innings_sequence = fm.match_innings_sequence
    and w.batting_position = fm.batting_position
join bowler_matches bm
    on w.source_file_name = bm.source_file_name
    and w.match_innings_sequence = bm.match_innings_sequence
    and w.batting_position = bm.batting_position
left join fielding_team_innings_number tin
    on w.source_file_name = tin.source_file_name
    and w.match_innings_sequence = tin.match_innings_sequence
