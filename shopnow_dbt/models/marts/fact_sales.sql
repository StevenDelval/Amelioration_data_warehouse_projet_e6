SELECT
    o.order_id,
    o.order_date,
    o.customer_sk,
    sp.product_sk,
    sp.seller_sk,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * sp.price) AS total_sales
FROM {{ ref('stg_order') }} o
JOIN {{ ref('stg_order_items') }} oi
    ON o.order_id = oi.order_id
JOIN {{ ref('stg_seller_product_pricing') }} sp
    ON oi.seller_product_sk = sp.seller_product_sk
GROUP BY
    o.order_id,
    o.order_date,
    o.customer_sk,
    sp.product_sk,
    sp.seller_sk