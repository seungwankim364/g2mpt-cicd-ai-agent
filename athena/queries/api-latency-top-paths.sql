SELECT
  request_url AS path,
  approx_percentile(target_processing_time, 0.50) AS p50_latency_seconds,
  approx_percentile(target_processing_time, 0.95) AS p95_latency_seconds,
  approx_percentile(target_processing_time, 0.99) AS p99_latency_seconds,
  count(*) AS request_count
FROM alb_access_logs
WHERE time BETWEEN from_iso8601_timestamp(:start_time) AND from_iso8601_timestamp(:end_time)
GROUP BY request_url
ORDER BY p95_latency_seconds DESC
LIMIT 50;

