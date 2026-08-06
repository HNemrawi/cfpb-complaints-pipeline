-- Grain: one row per canonical company, over the trailing 365 days.
with complaints as (

    select * from {{ ref('fct_complaints') }}
    where received_date >= current_date - interval 365 day

),

companies as (

    select * from {{ ref('dim_company') }}

),

final as (

    select
        c.company_key,
        c.company_name,
        count(*)                                             as complaint_count,
        avg(case when f.is_timely  then 1.0 else 0.0 end)    as timely_response_rate,
        avg(case when f.got_relief then 1.0 else 0.0 end)    as relief_rate,
        median(f.days_to_company)                            as median_days_to_company
    from complaints f
    inner join companies c
        on f.company_key = c.company_key
    group by
        c.company_key,
        c.company_name

)

select * from final
