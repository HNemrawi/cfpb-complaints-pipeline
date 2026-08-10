{% macro limit_dev_window(date_column) %}
    {%- if target.name == 'dev' -%}
        where {{ date_column }} >= current_date - interval {{ var('dev_lookback_days', 90) }} day
    {%- endif -%}
{% endmacro %}
