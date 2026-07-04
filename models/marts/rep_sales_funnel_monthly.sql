with

funnel_events as (
    select * from {{ ref('fct_funnel_events') }}
),

dates as (
    select month
    from {{ ref('dim_date') }}
    where month between
        (select date_trunc('month', min(event_at))::date from funnel_events)
        and (select date_trunc('month', max(event_at))::date from funnel_events)
),

-- The distinct set of funnel steps, with their ordering, drawn from the fact.
funnel_steps as (
    select distinct
        funnel_step,
        funnel_step_order,
        substep_order
    from funnel_events
),

-- Complete grid: every month crossed with every funnel step.
spine as (
    select
        dates.month,
        funnel_steps.funnel_step,
        funnel_steps.funnel_step_order,
        funnel_steps.substep_order
    from dates
    cross join funnel_steps
),

-- Actual deals entering each step per month.
monthly_counts as (
    select
        date_trunc('month', event_at)::date as month,
        funnel_step,
        funnel_step_order,
        substep_order,
        count(distinct deal_id)             as deals_count
    from funnel_events
    group by 1, 2, 3, 4
),

final as (
    select
        spine.month,
        spine.funnel_step                       as kpi_name,
        spine.funnel_step_order::text ||
            case when spine.substep_order > 0
                 then '.' || spine.substep_order::text
                 else '' end                    as funnel_step,
        coalesce(monthly_counts.deals_count, 0) as deals_count
    from spine
    left join monthly_counts
        on  spine.month             = monthly_counts.month
        and spine.funnel_step_order = monthly_counts.funnel_step_order
        and spine.substep_order     = monthly_counts.substep_order
    order by spine.month, spine.funnel_step_order, spine.substep_order
)

select * from final