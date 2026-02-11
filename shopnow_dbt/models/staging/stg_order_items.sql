SELECT
    order_id,
    seller_product_sk,
    quantity
FROM {{ source('shopnow_raw', 'fact_order_items') }}
WHERE quantity > 0