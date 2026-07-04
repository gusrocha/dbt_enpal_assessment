with

date_spine as (

    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="cast('" ~ var('date_spine_start') ~ "' as date)",
        end_date="cast('" ~ var('date_spine_end') ~ "' as date)"
    ) }}

)

select
    date_month::date                    as month,
    extract(year  from date_month)::int as year,
    extract(month from date_month)::int as month_number,
    to_char(date_month, 'YYYY-MM')      as year_month
from date_spine