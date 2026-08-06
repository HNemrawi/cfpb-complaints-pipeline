-- Grain: one row per raw company name as it appears in the complaint data.
with complaints as (

    select * from {{ ref('stg_cfpb__complaints') }}

),

overrides as (

    select * from {{ ref('seed_company_name_overrides') }}

),

final as (

    select distinct
        c.company_name_raw,
        coalesce(o.canonical_name, c.company_name_raw)  as company_name
    from complaints c
    left join overrides o
        on upper(c.company_name_raw) = upper(o.variant_name)
    where c.company_name_raw is not null

)

select * from final
