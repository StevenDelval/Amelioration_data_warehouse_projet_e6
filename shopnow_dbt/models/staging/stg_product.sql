SELECT
    product_sk,
    product_id,
    TRIM(name) AS product_name,
    category,
    description,
    start_date,
    end_date,
    is_current
FROM {{ source('shopnow_raw', 'dim_product') }}
WHERE product_id IS NOT NULL
