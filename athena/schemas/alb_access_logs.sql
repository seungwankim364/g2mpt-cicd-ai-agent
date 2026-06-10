CREATE EXTERNAL TABLE IF NOT EXISTS alb_access_logs (
  type string,
  time timestamp,
  elb string,
  client_ip string,
  client_port int,
  target_ip string,
  target_port int,
  request_processing_time double,
  target_processing_time double,
  response_processing_time double,
  elb_status_code string,
  target_status_code string,
  received_bytes bigint,
  sent_bytes bigint,
  request_verb string,
  request_url string,
  request_proto string,
  user_agent string,
  ssl_cipher string,
  ssl_protocol string,
  target_group_arn string,
  trace_id string
)
STORED AS TEXTFILE
LOCATION 's3://replace-with-log-bucket/alb/';

