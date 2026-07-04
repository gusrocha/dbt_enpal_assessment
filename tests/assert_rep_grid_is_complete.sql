-- rep_sales_funnel_monthly must be a full grid: every reporting month crossed with all funnel steps, zero-filled. Row count therefore equals (# distinct months) * (# funnel steps).
with counts as (
    select
        (select count(*) from {{ ref('dim_funnel_steps') }}) as n_steps,
        count(distinct month)                                as n_months,
        count(*)                                             as n_rows
    from {{ ref('rep_sales_funnel_monthly') }}
)

select *
from counts
where n_rows <> n_steps * n_months