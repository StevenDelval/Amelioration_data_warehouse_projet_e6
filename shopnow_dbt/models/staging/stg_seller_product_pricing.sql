SELECT
    seller_product_sk,
    seller_sk,
    product_sk,
    price,
    start_date,
    end_date,
    is_current
FROM {{ source('shopnow_raw', 'dim_seller_product_pricing') }}
WHERE price >= 0