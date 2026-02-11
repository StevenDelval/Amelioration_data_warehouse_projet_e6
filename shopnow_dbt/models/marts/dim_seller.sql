SELECT *
FROM {{ ref('stg_seller') }}
WHERE is_current = 1