with

activities as (
    select * from {{ ref('stg_pipedrive__activities') }}
    where is_done  -- a call counts as entering the sub-step only once completed
    -- Note: the data has no completion timestamp, so due_at (scheduled time) is used as a proxy for when the call occurred. At monthly grain this approximation is immaterial in the large majority of cases.
),

activity_types as (
    select * from {{ ref('stg_pipedrive__activity_types') }}
    where activity_type_key in ('meeting', 'sc_2') -- only call events that are relevant for the funnel
),

call_events as (
    select
        activities.deal_id,
        activity_types.activity_type_name  as call_name,
        activities.due_at                  as occurred_at
    from activities
    inner join activity_types
        on activities.activity_type_key = activity_types.activity_type_key
)

select * from call_events