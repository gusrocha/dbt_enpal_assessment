with

source as (
    select * from {{ source('pipedrive', 'activity') }}
),

renamed as (
    select
        activity_id::bigint       as activity_id,
        deal_id::bigint           as deal_id,
        assigned_to_user::bigint  as user_id,
        type::text                as activity_type_key,
        done::boolean             as is_done,
        due_to::timestamp         as due_at
    from source
)

select * from renamed