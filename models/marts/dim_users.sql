with

users as (
    select * from {{ ref('stg_pipedrive__users') }}
)

select
    user_id,
    user_name,
    email
from users