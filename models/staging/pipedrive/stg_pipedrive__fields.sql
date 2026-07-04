with

source as (
    select * from {{ source('pipedrive', 'fields') }}
),

renamed as (
    select
        id::int                  as field_id,
        field_key::text          as field_key,
        name::text               as field_name,
        field_value_options::text as field_value_options
    from source
)

select * from renamed