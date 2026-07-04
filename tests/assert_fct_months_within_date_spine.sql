-- Fails if any funnel event lands in a month dim_date doesn't cover. Such a month would be silently dropped from rep_sales_funnel_monthly.
select distinct
    date_trunc('month', event_at)::date as event_month
from {{ ref('fct_funnel_events') }}
where date_trunc('month', event_at)::date not in (
    select month from {{ ref('dim_date') }}
)