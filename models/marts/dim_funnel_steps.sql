with

funnel_steps as (
    select * from {{ ref('funnel_steps') }}
)

select
    -- Composed funnel-step identifier: '2' for a main step, '2.1' for a sub-step.
    funnel_step_order::text ||
        case when substep_order > 0
             then '.' || substep_order::text
             else '' end        as funnel_step,
    funnel_step_order,
    substep_order,
    kpi_name
from funnel_steps