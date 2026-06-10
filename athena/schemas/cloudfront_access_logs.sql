CREATE EXTERNAL TABLE IF NOT EXISTS cloudfront_access_logs (
  date date,
  time string,
  location string,
  bytes bigint,
  request_ip string,
  method string,
  host string,
  uri string,
  status int,
  referrer string,
  user_agent string,
  query_string string,
  cookie string,
  result_type string
)
STORED AS TEXTFILE
LOCATION 's3://replace-with-log-bucket/cloudfront/';

