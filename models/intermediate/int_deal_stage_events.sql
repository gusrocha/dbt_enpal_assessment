with

deal_changes as (
    select * from {{ ref('stg_pipedrive__deal_changes') }}
    where changed_field_key = 'stage_id'
),

stages as (
    select * from {{ ref('stg_pipedrive__stages') }}
),

stage_events as (
    select
        deal_id,
        new_value::int  as stage_id,
        changed_at      as entered_at
    from deal_changes
),

final as (
    select
        stage_events.deal_id,
        stage_events.stage_id,
        stages.stage_name,
        stage_events.entered_at
    from stage_events
    left join stages
        on stage_events.stage_id = stages.stage_id
)

select * from final