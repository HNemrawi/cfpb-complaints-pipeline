-- Grain: one row per calendar day, var('start_date') through today inclusive.
select
    date_day::date                          as date_day,
    extract(year  from date_day)            as year_number,
    extract(month from date_day)            as month_number,
    date_trunc('month', date_day)::date     as month_start_date,
    date_trunc('quarter', date_day)::date   as quarter_start_date,
    strftime(date_day, '%Y-%m')             as year_month,
    dayofweek(date_day) in (0, 6)           as is_weekend
from {{ ref('int_dates__spine') }}
