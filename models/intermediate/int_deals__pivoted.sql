with

deal_changes as (
    select * from {{ ref('stg_pipedrive__deal_changes') }}
),

activities as (
    select * from {{ ref('stg_pipedrive__activities') }}
),


-- The complete deal universe: every deal_id referenced anywhere in the data, not only those with a creation (add_time) event.
deal_spine as (
    select deal_id from deal_changes
    union
    select deal_id from activities
),

-- Deal creation: the add_time change carries the creation timestamp as its value. A handful of deals have duplicate add_time events, so we keep the earliest as the true creation moment and guarantee one row per deal.
created as (
    select
        deal_id,
        new_value::timestamp as created_at
    from (
        select
            deal_id,
            new_value,
            row_number() over (
                partition by deal_id
                order by changed_at asc
            ) as rn
        from deal_changes
        where changed_field_key = 'add_time'
    ) ranked
    where rn = 1
),

-- Current owner: the most recent user_id change wins.
current_owner as (
    select
        deal_id,
        new_value::bigint as user_id
    from (
        select
            deal_id,
            new_value,
            row_number() over (
                partition by deal_id
                order by changed_at desc
            ) as rn
        from deal_changes
        where changed_field_key = 'user_id'
    ) ranked
    where rn = 1
),

-- Lost reason: the most recent lost_reason change wins (a deal can be lost more than once in this data).
lost as (
    select
        deal_id,
        new_value::int as lost_reason_id
    from (
        select
            deal_id,
            new_value,
            row_number() over (
                partition by deal_id
                order by changed_at desc
            ) as rn
        from deal_changes
        where changed_field_key = 'lost_reason'
    ) ranked
    where rn = 1
),

deals as (
    select
        deal_spine.deal_id,
        created.created_at,
        current_owner.user_id,
        lost.lost_reason_id
    from deal_spine
    left join created       using (deal_id)
    left join current_owner using (deal_id)
    left join lost          using (deal_id)
)

select * from deals