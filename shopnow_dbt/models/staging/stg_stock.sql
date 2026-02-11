SELECT
    seller_product_sk,
    stock,
    event_timestamp,
    source
FROM {{ source('shopnow_raw', 'fact_seller_product_stock') }}
WHERE stock >= 0