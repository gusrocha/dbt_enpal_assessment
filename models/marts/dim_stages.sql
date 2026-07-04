with

stages as (
    select * from {{ ref('stg_pipedrive__stages') }}
)

select
    stage_id,
    stage_name
from stages