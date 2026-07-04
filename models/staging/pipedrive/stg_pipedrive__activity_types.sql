with

source as (
    select * from {{ source('pipedrive', 'activity_types') }}
),

renamed as (
    select
        id::int        as activity_type_id,
        type::text     as activity_type_key,
        name::text     as activity_type_name,
        active::boolean as is_active
    from source
)

select * from renamed