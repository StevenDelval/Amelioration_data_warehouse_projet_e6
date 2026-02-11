SELECT *
FROM {{ ref('stg_customer') }}
WHERE is_current = 1