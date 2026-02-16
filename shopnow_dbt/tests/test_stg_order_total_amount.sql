SELECT *
FROM {{ ref('stg_order') }}
WHERE total_amount < 0