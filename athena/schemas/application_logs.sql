CREATE EXTERNAL TABLE IF NOT EXISTS application_logs (
  timestamp timestamp,
  service string,
  environment string,
  level string,
  message string,
  trace_id string
)
STORED AS JSON
LOCATION 's3://replace-with-log-bucket/application/';

