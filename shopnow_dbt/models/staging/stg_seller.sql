SELECT
    seller_sk,
    seller_id,
    TRIM(name) AS seller_name,
    status,
    country,
    city,
    address,
    start_date,
    end_date,
    is_current
FROM {{ source('shopnow_raw', 'dim_seller') }}
WHERE seller_id IS NOT NULL
