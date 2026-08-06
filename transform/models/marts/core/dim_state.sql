-- Grain: one row per state, territory or military postal code the dashboard can display.
with jurisdictions as (

    select * from {{ ref('seed_state_population') }}

),

final as (

    select
        state_code,
        state_name,
        census_region,
        jurisdiction_type,
        population,
        population is null  as is_unpopulated   -- no denominator: exclude from per-capita
    from jurisdictions

)

select * from final
