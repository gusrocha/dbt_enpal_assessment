with

stage_events as (
    select * from {{ ref('int_deal_stage_events') }}
),

call_events as (
    select * from {{ ref('int_deal_call_events') }}
),

funnel_events as (

    select
        deal_id,
        stage_name       as funnel_step,
        stage_id         as funnel_step_order,
        0                as substep_order,  -- main steps are always 0
        'stage'          as event_source,
        entered_at       as event_at
    from stage_events

    union all

    select
        deal_id,
        call_name        as funnel_step,
        case call_name
            when 'Sales Call 1' then 2   -- ties it directly to Step 2
            when 'Sales Call 2' then 3   -- ties it directly to Step 3
        end              as funnel_step_order,
        1                as substep_order,  -- flag identifying it as a sub-action
        'call'           as event_source,
        occurred_at      as event_at
    from call_events

),

with_key as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'deal_id',
            'funnel_step_order',
            'substep_order',
            'event_at'
        ]) }} as funnel_event_id,
        *
    from funnel_events
)

select * from with_key