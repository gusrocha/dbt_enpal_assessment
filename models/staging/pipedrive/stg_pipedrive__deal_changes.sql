with

source as (
    select * from {{ source('pipedrive', 'deal_changes') }}
),

renamed as (
    select
        deal_id::bigint          as deal_id,
        changed_field_key::text  as changed_field_key,
        new_value::text          as new_value,
        change_time::timestamp   as changed_at
    from source
)

select * from renamed