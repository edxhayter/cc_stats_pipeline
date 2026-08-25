-- Grain: one row per source file. innings_per_team describes the FORMAT's
-- normal rule (2 for TEST/FC_LEAGUE, 1 otherwise) — it does not reflect the
-- realized per-match count, which can be lower for an innings-victory match
-- (see int_innings_totals / docs/dbt-modeling-plan.md).

select
    {{ dbt_utils.generate_surrogate_key(['mh.source_file_name']) }} as match_id,
    mh.source_file_name,
    mh.match_date,
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
    mp.player_id as man_of_the_match_id
from {{ ref('int_match_header') }} mh
join {{ ref('int_result') }} r on mh.source_file_name = r.source_file_name
join {{ ref('dim_team') }} ht on mh.home_team = ht.team_name
join {{ ref('dim_team') }} at on mh.away_team = at.team_name
left join {{ ref('dim_team') }} wt on r.winning_team = wt.team_name
left join {{ ref('dim_player') }} mp on r.man_of_the_match = mp.player_name
