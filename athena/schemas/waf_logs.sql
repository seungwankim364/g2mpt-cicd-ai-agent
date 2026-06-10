CREATE EXTERNAL TABLE IF NOT EXISTS waf_logs (
  timestamp bigint,
  formatversion int,
  webaclid string,
  terminatingruleid string,
  action string,
  httprequest struct<clientip:string,country:string,uri:string,args:string,httpmethod:string>
)
STORED AS JSON
LOCATION 's3://replace-with-log-bucket/waf/';

