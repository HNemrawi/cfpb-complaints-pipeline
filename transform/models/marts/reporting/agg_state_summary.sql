-- Grain: one row per state per product group, including combinations with zero complaints.

{% set response_buckets = [
    'explanation_only', 'in_progress', 'nonmonetary_relief',
    'monetary_relief', 'other', 'no_response'
] %}

with complaints as (


    select * from {{ ref('fct_complaints') }}

),

products as (

    select * from {{ ref('dim_product') }}

),

states as (

    select * from {{ ref('dim_state') }}

),

groups as (

    select distinct
        product_group,
        display_order
    from products

),

-- every jurisdiction x every group, so a state with no complaints still maps
scaffold as (

    select
        s.state_code,
        s.state_name,
        s.census_region,
        s.jurisdiction_type,
        s.population,
        s.is_unpopulated,
        g.product_group,
        g.display_order
    from states s
    cross join groups g

),

counted as (

    select
        f.state_code,
        p.product_group,
        count(*)  as complaint_count
        {%- for bucket in response_buckets %},
            sum(case when f.response_bucket = '{{ bucket }}' then 1 else 0 end) as {{ bucket }}_count
        {%- endfor %}  
    from complaints f
    inner join products p
        on f.product_key = p.product_key
    where f.state_code is not null      -- 1,732 complaints have no state; they cannot map
    group by
        1,
        2

),

final as (

    select
        s.state_code,
        s.state_name,
        s.census_region,
        s.jurisdiction_type,
        s.population,
        s.product_group,
        s.display_order,
        coalesce(c.complaint_count, 0)  as complaint_count,

        -- is_unpopulated carries the "no denominator" rule from dim_state, so the
        -- exclusion is declared once upstream rather than re-derived here
        case
            when s.is_unpopulated then null
            else round(coalesce(c.complaint_count, 0) * 100000.0 / s.population, 2)
        end                             as complaints_per_100k
        {%- for bucket in response_buckets %},
            coalesce(c.{{ bucket }}_count, 0) as {{ bucket }}_count
        {%- endfor %}
    from scaffold s
    left join counted c
        on s.state_code    = c.state_code
       and s.product_group = c.product_group

)

select * from final
