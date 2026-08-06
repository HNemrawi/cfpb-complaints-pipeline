{% macro share_of(flag_column) -%}
    avg(case when {{ flag_column }} then 1.0 else 0.0 end)
{%- endmacro %}
