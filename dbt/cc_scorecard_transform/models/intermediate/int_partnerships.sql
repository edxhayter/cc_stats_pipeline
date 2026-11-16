-- One row per wicket stand x team-innings x match: the runs added for each
-- wicket, from the fall of wickets, plus the last stand after the final
-- wicket when there is one.
--
-- Deliberately no batter names. The scorecard doesn't record who was out at
-- each wicket, so who batted in a stand has to be inferred, and it often
-- can't be: across the season, about four in ten stands could have been
-- more than one pair of batters. The earlier pairing (positions N and N+1,
-- assuming the lower position is always out first) was wrong for at least
-- 1,295 of 5,382 stands — e.g. Jaiswal (No. 2) out first for 13 in the
-- 16 Jul 2026 ODI, so the 155 second-wicket stand was Gill and Kohli, not
-- Jaiswal and Kohli. Stands are reported by wicket ("the second-wicket
-- stand of 155") instead; the runs are exact.

with innings as (

    select
        source_file_name,
        team,
        team_innings_number,
        match_innings_sequence,
        total_runs
    from {{ ref('int_innings_totals') }}

),

batted as (

    select
        source_file_name,
        match_innings_sequence,
        -- Counted from dismissals, not names or batting positions: two
        -- batters can share a scorecard name (both of Sri Lanka's "K
        -- Mendis" in the 25 Jun 2026 Test), and a retired-hurt batter can
        -- leave and come back.
        count_if(dismissal_type = 'NOT_OUT') as not_outs
    from {{ ref('int_batting_rows') }}
    where not did_not_bat
    group by 1, 2

),

wickets as (

    select
        source_file_name,
        match_innings_sequence,
        wicket_number,
        cumulative_score,
        cumulative_score - coalesce(
            lag(cumulative_score) over (
                partition by source_file_name, match_innings_sequence
                order by wicket_number
            ),
            0
        ) as stand_runs
    from {{ ref('int_fow_rows') }}

),

wickets_per_innings as (

    select
        source_file_name,
        match_innings_sequence,
        count(*) as wickets,
        max(cumulative_score) as last_score
    from wickets
    group by 1, 2

),

broken_stands as (

    select
        i.source_file_name,
        i.team,
        i.team_innings_number,
        i.match_innings_sequence,
        w.wicket_number as partnership_number,
        w.stand_runs as partnership_runs,
        false as is_unbroken
    from innings i
    join wickets w
        on i.source_file_name = w.source_file_name
        and i.match_innings_sequence = w.match_innings_sequence

),

-- The stand after the final wicket: unbroken when two batters finished not
-- out (declaration, target reached, overs up); otherwise it ended without a
-- wicket because a batter retired hurt and nobody was left (the 9-wicket
-- innings in the 3 Jul 2026 WI v SL Test and 19 Jun 2026 Ssx v Ham).
last_stands as (

    select
        i.source_file_name,
        i.team,
        i.team_innings_number,
        i.match_innings_sequence,
        coalesce(wp.wickets, 0) + 1 as partnership_number,
        i.total_runs - coalesce(wp.last_score, 0) as partnership_runs,
        b.not_outs = 2 as is_unbroken
    from innings i
    join batted b
        on i.source_file_name = b.source_file_name
        and i.match_innings_sequence = b.match_innings_sequence
    left join wickets_per_innings wp
        on i.source_file_name = wp.source_file_name
        and i.match_innings_sequence = wp.match_innings_sequence
    where b.not_outs = 2
        or i.total_runs > coalesce(wp.last_score, 0)

)

select * from broken_stands
union all
select * from last_stands
