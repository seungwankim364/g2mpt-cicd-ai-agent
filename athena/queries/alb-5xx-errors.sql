SELECT
  request_url AS path,
  target_group_arn AS target_group,
  target_ip,
  elb_status_code,
  target_status_code,
  count(*) AS error_count
FROM alb_access_logs
WHERE time BETWEEN from_iso8601_timestamp(:start_time) AND from_iso8601_timestamp(:end_time)
  AND (elb_status_code LIKE '5%' OR target_status_code LIKE '5%')
GROUP BY request_url, target_group_arn, target_ip, elb_status_code, target_status_code
ORDER BY error_count DESC
LIMIT 50;

