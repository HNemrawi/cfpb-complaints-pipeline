-- Grain: one row per canonical company.
with complaints as (

    select * from {{ ref('stg_cfpb__complaints') }}

),

overrides as (

    select * from {{ ref('seed_company_name_overrides') }}

),

canonicalised as (

    select distinct
        coalesce(o.canonical_name, c.company_name_raw)  as company_name,
        c.company_name_raw
    from complaints c
    left join overrides o
        on upper(c.company_name_raw) = upper(o.variant_name)
    where c.company_name_raw is not null

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['company_name']) }}  as company_key,
        company_name,
        count(*)                                                 as name_variant_count
    from canonicalised
    group by company_name

)

select * from final
