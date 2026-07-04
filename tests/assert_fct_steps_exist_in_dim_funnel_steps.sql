-- Every (funnel_step_order, substep_order) in the fact must exist in the canonical funnel dimension. A failure means an event carries a step the brief's funnel doesn't define, which would then be absent from the report grid.
select
    f.funnel_step_order,
    f.substep_order
from {{ ref('fct_funnel_events') }} as f
left join {{ ref('dim_funnel_steps') }} as d
    on  f.funnel_step_order = d.funnel_step_order
    and f.substep_order     = d.substep_order
where d.funnel_step_order is null
group by 1, 2