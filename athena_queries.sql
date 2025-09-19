-- Create external table for stock data in Athena
CREATE EXTERNAL TABLE IF NOT EXISTS stock_analytics_db.stock_data (
  ticker string,
  timestamp bigint,
  price double,
  volume bigint,
  high double,
  low double,
  open double
)
STORED AS JSON
LOCATION 's3://YOUR_RAW_DATA_BUCKET/stock-data/'
TBLPROPERTIES ('has_encrypted_data'='false');

-- Query to analyze daily price movements
SELECT 
  ticker,
  DATE(from_unixtime(timestamp)) as date,
  MIN(price) as daily_low,
  MAX(price) as daily_high,
  AVG(price) as avg_price,
  SUM(volume) as total_volume
FROM stock_analytics_db.stock_data
WHERE ticker = 'ORCL'
GROUP BY ticker, DATE(from_unixtime(timestamp))
ORDER BY date DESC;

-- Query to calculate moving averages
SELECT 
  ticker,
  from_unixtime(timestamp) as datetime,
  price,
  AVG(price) OVER (
    PARTITION BY ticker 
    ORDER BY timestamp 
    ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
  ) as sma_5,
  AVG(price) OVER (
    PARTITION BY ticker 
    ORDER BY timestamp 
    ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
  ) as sma_20
FROM stock_analytics_db.stock_data
WHERE ticker = 'ORCL'
ORDER BY timestamp DESC
LIMIT 100;