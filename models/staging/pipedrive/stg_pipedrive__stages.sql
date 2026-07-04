with

source as (
    select * from {{ source('pipedrive', 'stages') }}
),

renamed as (
    select
        stage_id::int     as stage_id,
        stage_name::text  as stage_name
    from source
)

select * from renamed