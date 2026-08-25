-- One row per partnership x team-innings x match. The Nth wicket
-- partnership is the pair at batting_position N and N+1 — this looks
-- like it should need a full innings simulation (as originally described
-- in docs/dbt-modeling-plan.md), but it mathematically reduces to a
-- simple self-join once you trace through it: batters always enter in
-- position order, and under the standard assumption that dismissals
-- happen in non-decreasing position order (no "batting out of order"
-- reversals — the same assumption every scorecard-only partnership tool
-- relies on, Cricinfo included, since none of them have ball-by-ball
-- either), the higher-positioned member of any pair always survives to
-- partner the next batter in. Working through the induction: partnership
-- 1 = (1,2); position 1 (lower) is assumed out first, 2 survives to
-- partner 3 → partnership 2 = (2,3); and so on — always (N, N+1).
--
-- Known limitation, not specially handled: retired-hurt-then-return
-- breaks the "positions enter in strict order" assumption this relies on
-- (confirmed to occur in 1 of 173 files — see int_batting_rows). Flagged
-- rather than silently assumed correct for that match.

with batters as (

    select
        source_file_name,
        batting_team,
        team_innings_number,
        match_innings_sequence,
        batting_position,
        player_name,
        dismissal_type
    from {{ ref('int_batting_rows') }}
    where not did_not_bat

),

paired as (

    select
        b1.source_file_name,
        b1.batting_team,
        b1.team_innings_number,
        b1.match_innings_sequence,
        b1.batting_position as partnership_number,
        b1.player_name as batter_1_name,
        b2.player_name as batter_2_name,
        -- Usually b1 (the lower position) is the one dismissed to end
        -- this partnership. But at the tail of an all-out innings, the
        -- not-out survivor isn't always the higher position — e.g. a
        -- confirmed real case: position 10 not out, position 11 got out,
        -- ending the innings — the reverse of what "lower falls first"
        -- would assume. So: use whichever of the pair has an actual
        -- dismissal; NULL only if both are NOT_OUT (genuinely unbroken,
        -- e.g. declaration or a chase completed early).
        case
            when b1.dismissal_type != 'NOT_OUT' then b1.dismissal_type
            when b2.dismissal_type != 'NOT_OUT' then b2.dismissal_type
        end as how_ended
    from batters b1
    join batters b2
        on b1.source_file_name = b2.source_file_name
        -- match_innings_sequence (not team_innings_number alone) since
        -- team_innings_number repeats between the two teams — both have
        -- a "1st innings" — and would otherwise let this self-join pair
        -- batters across different teams/innings entirely.
        and b1.match_innings_sequence = b2.match_innings_sequence
        and b2.batting_position = b1.batting_position + 1

)

select
    p.source_file_name,
    p.batting_team as team,
    p.team_innings_number,
    p.match_innings_sequence,
    p.partnership_number,
    p.batter_1_name,
    p.batter_2_name,
    p.how_ended,
    -- unbroken final partnership has no matching fall-of-wickets row at
    -- wicket_number = partnership_number; fall back to the innings total
    -- for the runs added since the previous wicket in that case
    coalesce(f.cumulative_score, it.total_runs) - coalesce(f_prev.cumulative_score, 0) as partnership_runs
from paired p
left join {{ ref('int_fow_rows') }} f
    on p.source_file_name = f.source_file_name
    and p.match_innings_sequence = f.match_innings_sequence
    and f.wicket_number = p.partnership_number
left join {{ ref('int_fow_rows') }} f_prev
    on p.source_file_name = f_prev.source_file_name
    and p.match_innings_sequence = f_prev.match_innings_sequence
    and f_prev.wicket_number = p.partnership_number - 1
left join {{ ref('int_innings_totals') }} it
    on p.source_file_name = it.source_file_name
    and p.batting_team = it.team
    and p.team_innings_number = it.team_innings_number
