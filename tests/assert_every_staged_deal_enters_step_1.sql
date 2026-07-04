-- The README asserts every deal begins at Lead Generation (stage 1). This guards it directly: any deal with stage history but no stage-1 entry would mean Step 1 undercounts the true top of funnel.
with staged_deals as (
    select distinct deal_id
    from {{ ref('int_deal_stage_events') }}
),

entered_step_1 as (
    select distinct deal_id
    from {{ ref('int_deal_stage_events') }}
    where stage_id = 1
)

select s.deal_id
from staged_deals as s
left join entered_step_1 as e
    on s.deal_id = e.deal_id
where e.deal_id is null