-- A deal's creation should precede its earliest funnel event. This is a data-quality SMELL, not a hard invariant: call events use due_at (scheduled time) as a proxy for completion, so a call scheduled before the logged creation can legitimately trip this. We surface it as a warning to quantify how often the proxy inverts the timeline, without failing the build.

-- Observed at build time: 1 of 6,559 deals (deal_id = 984965), a call scheduled before the deal's add_time. Confirms the proxy is sound.
{{ config(severity = 'warn') }}

with first_event as (
    select
        deal_id,
        min(event_at) as first_event_at
    from {{ ref('fct_funnel_events') }}
    group by deal_id
),

deals as (
    select
        deal_id,
        created_at
    from {{ ref('dim_deals') }}
    where created_at is not null   -- activity-only deals have no creation; not a violation
)

select
    d.deal_id,
    d.created_at,
    fe.first_event_at
from deals as d
inner join first_event as fe
    on d.deal_id = fe.deal_id
where fe.first_event_at < d.created_at