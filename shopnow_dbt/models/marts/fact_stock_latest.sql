WITH ranked_stock AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY seller_product_sk
               ORDER BY event_timestamp DESC
           ) AS rn
    FROM {{ ref('stg_stock') }}
)

SELECT
    seller_product_sk,
    stock,
    event_timestamp
FROM ranked_stock
WHERE rn = 1