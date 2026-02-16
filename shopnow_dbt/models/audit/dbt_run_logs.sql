{{ config(
    materialized='table',
    incremental_strategy='append',
    schema='audit',
    as_columnstore=false
) }}

-- Table vide avec structure définie et ID auto-incrément
SELECT
    *
FROM {{ source('shopnow_audit', 'dbt_run_logs') }}