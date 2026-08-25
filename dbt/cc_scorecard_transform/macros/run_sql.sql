{% macro run_sql(sql) %}
  {% set result = run_query(sql) %}
  {% if execute %}
    {{ log(result.print_table(max_rows=200, max_columns=None), info=True) }}
  {% endif %}
{% endmacro %}
