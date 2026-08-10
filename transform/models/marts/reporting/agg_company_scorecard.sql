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
        count(*)                        as complaint_count,
        {{ share_of('f.is_timely') }}   as timely_response_rate,
        {{ share_of('f.got_relief') }}  as relief_rate,
        median(f.days_to_company)       as median_days_to_company
    from complaints f
    inner join companies c
        on f.company_key = c.company_key
    group by
        c.company_key,
        c.company_name

)

select * from final
