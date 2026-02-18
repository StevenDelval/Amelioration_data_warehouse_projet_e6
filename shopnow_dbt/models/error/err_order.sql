SELECT
    order_id,
    customer_sk,
    CAST(order_date AS DATE) AS order_date,
    total_amount
FROM {{ source('shopnow_raw', 'fact_order') }}
WHERE order_id IS NULL OR total_amount <0