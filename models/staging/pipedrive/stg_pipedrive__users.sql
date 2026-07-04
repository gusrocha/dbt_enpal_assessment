with

source as (
    select * from {{ source('pipedrive', 'users') }}
),

renamed as (
    select
        id::bigint       as user_id,
        name::text       as user_name,
        email::text      as email,
        modified::timestamp as modified_at
    from source
)

select * from renamed