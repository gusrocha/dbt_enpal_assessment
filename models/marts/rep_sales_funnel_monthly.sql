with

funnel_events as (
    select * from {{ ref('fct_funnel_events') }}
),

-- Canonical funnel steps (seed).
funnel_steps as (
    select
        funnel_step,
        funnel_step_order,
        substep_order,
        kpi_name
    from {{ ref('dim_funnel_steps') }}
),

-- Reporting months, clipped to the range of observed events.
dates as (
    select month
    from {{ ref('dim_date') }}
    where month between
        (select date_trunc('month', min(event_at))::date from funnel_events)
        and (select date_trunc('month', max(event_at))::date from funnel_events)
),

-- Complete grid: every month crossed with every canonical funnel step.
spine as (
    select
        dates.month,
        funnel_steps.funnel_step,
        funnel_steps.funnel_step_order,
        funnel_steps.substep_order,
        funnel_steps.kpi_name
    from dates
    cross join funnel_steps
),

-- Actual distinct deals entering each step per month, keyed by step order.
monthly_counts as (
    select
        date_trunc('month', event_at)::date as month,
        funnel_step_order,
        substep_order,
        count(distinct deal_id)             as deals_count
    from funnel_events
    group by 1, 2, 3
),

final as (
    select
        spine.month,
        spine.kpi_name,
        spine.funnel_step,
        coalesce(monthly_counts.deals_count, 0) as deals_count
    from spine
    left join monthly_counts
        on  spine.month             = monthly_counts.month
        and spine.funnel_step_order = monthly_counts.funnel_step_order
        and spine.substep_order     = monthly_counts.substep_order
    order by spine.month, spine.funnel_step_order, spine.substep_order
)

select * from final