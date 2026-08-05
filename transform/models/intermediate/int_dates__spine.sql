-- Grain: one row per calendar day, var('start_date') through today inclusive.
-- end_date is EXCLUSIVE in dbt_utils.date_spine, hence the + 1 day.
{{ dbt_utils.date_spine(
    datepart="day",
    start_date="cast('" ~ var('start_date') ~ "' as date)",
    end_date="cast(current_date + interval 1 day as date)"
) }}
