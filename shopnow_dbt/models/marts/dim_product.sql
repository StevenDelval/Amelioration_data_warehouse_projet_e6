SELECT *
FROM {{ ref('stg_product') }}
WHERE is_current = 1