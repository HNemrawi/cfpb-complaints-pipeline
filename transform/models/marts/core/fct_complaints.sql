-- Grain: one row per complaint.
with base as (

    select * from {{ ref('stg_cfpb__complaints') }}

),

flags as (

    select * from {{ ref('int_complaints__response_flags') }}

),

company_names as (

    select * from {{ ref('int_companies__canonical_names') }}

),

companies as (

    select * from {{ ref('dim_company') }}

),

products as (

    select * from {{ ref('dim_product') }}

),

final as (

    select
        b.complaint_id,
        b.received_date,
        c.company_key,
        p.product_key,
        b.state_code,
        b.submission_channel,
        f.response_bucket,
        f.is_timely,
        f.got_relief,
        f.days_to_company
    from base b
    inner join flags         f on b.complaint_id = f.complaint_id
    left join  company_names n on b.company_name_raw = n.company_name_raw
    left join  companies     c on n.company_name = c.company_name
    left join  products      p on b.product = p.product
                              and b.sub_product is not distinct from p.sub_product

)

select * from final
