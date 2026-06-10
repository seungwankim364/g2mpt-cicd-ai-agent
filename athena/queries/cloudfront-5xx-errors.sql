SELECT
  uri,
  status,
  result_type,
  count(*) AS error_count
FROM cloudfront_access_logs
WHERE date BETWEEN date(from_iso8601_timestamp(:start_time)) AND date(from_iso8601_timestamp(:end_time))
  AND status BETWEEN 500 AND 599
GROUP BY uri, status, result_type
ORDER BY error_count DESC
LIMIT 50;

