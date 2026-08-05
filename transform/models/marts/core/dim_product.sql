-- Grain: one row per product / sub-product pair present in the complaint data.
with complaints as (

    select * from {{ ref('stg_cfpb__complaints') }}

),

groups as (

    select * from {{ ref('seed_product_groups') }}

),

taxonomy as (

    select distinct
        product,
        sub_product
    from complaints
    where product is not null

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['t.product', 't.sub_product']) }}  as product_key,
        t.product,
        t.sub_product,
        g.product_group,
        g.display_order
    from taxonomy t
    left join groups g
        on t.product = g.product

)

select * from final
