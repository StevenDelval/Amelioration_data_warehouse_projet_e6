SELECT
    customer_sk,
    customer_id,
    TRIM(name) AS customer_name,
    LOWER(email) AS email,
    city,
    country,
    address,
    start_date,
    end_date,
    is_current
FROM {{ source('shopnow_raw', 'dim_customer') }}
WHERE customer_id IS NOT NULL