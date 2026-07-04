with

fields_source as (
    select * from {{ ref('stg_pipedrive__fields') }}
    where field_key = 'lost_reason'
),

unnested_json as (
    select
        json_array_elements(field_value_options::json) as element
    from fields_source
),

final as (
    select
        trim(element ->> 'id')::int as lost_reason_id,
        trim(element ->> 'label')::text as lost_reason_name
    from unnested_json
)

select * from final