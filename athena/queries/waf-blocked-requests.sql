SELECT
  terminatingruleid AS terminating_rule_id,
  httprequest.clientip AS client_ip,
  httprequest.country AS country,
  httprequest.uri AS uri,
  count(*) AS blocked_count
FROM waf_logs
WHERE timestamp BETWEEN to_unixtime(from_iso8601_timestamp(:start_time)) * 1000
  AND to_unixtime(from_iso8601_timestamp(:end_time)) * 1000
  AND action = 'BLOCK'
GROUP BY terminatingruleid, httprequest.clientip, httprequest.country, httprequest.uri
ORDER BY blocked_count DESC
LIMIT 50;

