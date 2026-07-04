with

funnel_events as (
    select * from {{ ref('int_funnel_events') }}
)

select
    funnel_event_id,
    deal_id,
    funnel_step_name,
    funnel_step_order,
    substep_order,
    event_source,
    event_at
from funnel_events