SELECT
  regexp_extract(message, '(Exception|Error|Timeout|Connection refused|Connection reset)', 1) AS error_pattern,
  count(*) AS error_count,
  min(timestamp) AS first_seen,
  max(timestamp) AS last_seen,
  arbitrary(message) AS sample_message
FROM application_logs
WHERE timestamp BETWEEN from_iso8601_timestamp(:start_time) AND from_iso8601_timestamp(:end_time)
  AND regexp_like(message, '(Exception|Error|Timeout|Connection refused|Connection reset)')
GROUP BY regexp_extract(message, '(Exception|Error|Timeout|Connection refused|Connection reset)', 1)
ORDER BY error_count DESC
LIMIT 50;

