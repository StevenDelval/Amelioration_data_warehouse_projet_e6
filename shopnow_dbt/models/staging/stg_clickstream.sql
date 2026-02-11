SELECT
    event_id,
    session_id,
    user_id,
    url,
    event_type,
    event_timestamp
FROM {{ source('shopnow_raw', 'fact_clickstream') }}
WHERE event_id IS NOT NULL