-- Grain: one row per canonical company.
with canonicalised as (

    select * from {{ ref('int_companies__canonical_names') }}

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
