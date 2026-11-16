-- Grain: one row per source file. innings_per_team describes the FORMAT's
-- normal rule (2 for TEST/FC_LEAGUE, 1 otherwise) — it does not reflect the
-- realized per-match count, which can be lower for an innings-victory match
-- (see int_innings_totals / docs/dbt-modeling-plan.md).
--
-- Series: international matches (TEST, ODI, T20I) between the same two
-- teams in the same format, with no more than 30 days between consecutive
-- matches. Derived rather than read from competition_variant, which can be
-- wrong ("Only" on the first of three ODIs). Domestic matches have no series.

with matches as (

    select
        {{ dbt_utils.generate_surrogate_key(['mh.source_file_name']) }} as match_id,
        mh.source_file_name,
        mh.match_date,
        mh.home_team,
        mh.away_team,
        ht.team_id as home_team_id,
        at.team_id as away_team_id,
        mh.competition_name,
        mh.competition_variant,
        mh.match_format,
        case when mh.match_format in ('TEST', 'FC_LEAGUE') then 2 else 1 end as innings_per_team,
        wt.team_id as winning_team_id,
        r.result_type,
        r.result_margin_type,
        r.result_margin_value,
        mp.player_id as man_of_the_match_id,
        least(mh.home_team, mh.away_team) as team_a,
        greatest(mh.home_team, mh.away_team) as team_b
    from {{ ref('int_match_header') }} mh
    join {{ ref('int_result') }} r on mh.source_file_name = r.source_file_name
    join {{ ref('dim_team') }} ht on mh.home_team = ht.team_name
    join {{ ref('dim_team') }} at on mh.away_team = at.team_name
    left join {{ ref('dim_team') }} wt on r.winning_team = wt.team_name
    left join {{ ref('dim_player') }} mp on r.man_of_the_match = mp.player_name

),

series_breaks as (

    select
        *,
        case
            when datediff(
                day,
                lag(match_date) over (
                    partition by match_format, team_a, team_b
                    order by match_date, source_file_name
                ),
                match_date
            ) <= 30 then 0
            else 1
        end as starts_series
    from matches
    where match_format in ('TEST', 'ODI', 'T20I')

),

series_numbered as (

    select
        match_id,
        match_format,
        team_a,
        team_b,
        sum(starts_series) over (
            partition by match_format, team_a, team_b
            order by match_date, source_file_name
        ) as series_seq,
        row_number() over (
            partition by match_format, team_a, team_b
            order by match_date, source_file_name
        ) as pair_match_seq
    from series_breaks

),

series as (

    select
        sn.match_id,
        {{ dbt_utils.generate_surrogate_key(['sn.match_format', 'sn.team_a', 'sn.team_b', 'sn.series_seq']) }} as series_id,
        row_number() over (
            partition by sn.match_format, sn.team_a, sn.team_b, sn.series_seq
            order by sn.pair_match_seq
        ) as series_match_number,
        count(*) over (
            partition by sn.match_format, sn.team_a, sn.team_b, sn.series_seq
        ) as series_matches_played,
        -- "(of N)" from the scorecards; the largest N in the series wins,
        -- since a single label can be wrong. "Only" alone means one match.
        greatest(
            count(*) over (
                partition by sn.match_format, sn.team_a, sn.team_b, sn.series_seq
            ),
            coalesce(max(try_to_number(regexp_substr(m.competition_variant, '\\(of (\\d+)\\)', 1, 1, 'e', 1))) over (
                partition by sn.match_format, sn.team_a, sn.team_b, sn.series_seq
            ), 1)
        ) as series_scheduled_matches,
        -- Named after the first match: home team first, e.g.
        -- "England v New Zealand Test series, Jun 2026".
        first_value(m.home_team || ' v ' || m.away_team) over (
            partition by sn.match_format, sn.team_a, sn.team_b, sn.series_seq
            order by sn.pair_match_seq
        ) || ' '
        || case sn.match_format when 'TEST' then 'Test' else sn.match_format end
        || ' series, '
        || to_char(first_value(m.match_date) over (
            partition by sn.match_format, sn.team_a, sn.team_b, sn.series_seq
            order by sn.pair_match_seq
        ), 'Mon YYYY') as series_name
    from series_numbered sn
    join matches m on sn.match_id = m.match_id

)

select
    m.match_id,
    m.source_file_name,
    m.match_date,
    m.home_team_id,
    m.away_team_id,
    m.competition_name,
    m.competition_variant,
    m.match_format,
    m.innings_per_team,
    m.winning_team_id,
    m.result_type,
    m.result_margin_type,
    m.result_margin_value,
    m.man_of_the_match_id,
    s.series_id,
    s.series_name,
    s.series_match_number,
    s.series_matches_played,
    s.series_scheduled_matches
from matches m
left join series s on m.match_id = s.match_id
