-- Grain: one row per month per product group, including months with zero complaints.
with complaints as (

    select * from {{ ref('fct_complaints') }}

),

products as (

    select * from {{ ref('dim_product') }}

),

dates as (

    select * from {{ ref('dim_date') }}

),

months as (

    select distinct
        month_start_date,
        year_month
    from dates

),

groups as (

    select distinct
        product_group,
        display_order
    from products

),

-- every month x every group, so a month with no complaints still has a row
scaffold as (

    select
        m.month_start_date,
        m.year_month,
        g.product_group,
        g.display_order
    from months m
    cross join groups g

),

counted as (

    select
        date_trunc('month', f.received_date)::date            as month_start_date,
        p.product_group,
        count(*)                                              as complaint_count,
        avg(case when f.is_timely  then 1.0 else 0.0 end)     as timely_response_rate,
        avg(case when f.got_relief then 1.0 else 0.0 end)     as relief_rate
    from complaints f
    inner join products p
        on f.product_key = p.product_key
    group by
        1,
        2

),

final as (

    select
        s.month_start_date,
        s.year_month,
        s.product_group,
        s.display_order,
        coalesce(c.complaint_count, 0)  as complaint_count,
        -- rates stay NULL, not 0: a rate over zero complaints is undefined, and
        -- charting it as 0% would invent a fact the data does not contain
        c.timely_response_rate,
        c.relief_rate
    from scaffold s
    left join counted c
        on s.month_start_date = c.month_start_date
       and s.product_group    = c.product_group

)

select * from final
