with

deals as (
    select * from {{ ref('int_deals__pivoted') }}
),

lost_reasons as (
    select * from {{ ref('int_lost_reasons__unnested') }}
),

users as (
    select * from {{ ref('stg_pipedrive__users') }}
),

final as (
    select
        deals.deal_id,
        deals.created_at,
        deals.user_id             as owner_id,
        users.user_name           as owner_name,
        deals.lost_reason_id,
        lost_reasons.lost_reason_name
    from deals
    left join users
        on deals.user_id = users.user_id
    left join lost_reasons
        on deals.lost_reason_id = lost_reasons.lost_reason_id
)

select * from final