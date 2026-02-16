{% macro log_dbt_results() %}

    {% if execute %}

        {% for result in results %}

            insert into audit.dbt_run_logs (
                run_id,
                run_started_at,
                run_ended_at,
                resource_type,
                resource_name,
                status,
                executed_by,
                message
            )
            values (
                '{{ invocation_id }}',
                '{{ run_started_at }}',
                getdate(),
                '{{ result.node.resource_type }}',
                '{{ result.node.name }}',
                '{{ result.status }}',
                '{{ target.user }}',
                '{{ result.message | replace("'", "''") }}'
            );

        {% endfor %}

    {% endif %}

{% endmacro %}