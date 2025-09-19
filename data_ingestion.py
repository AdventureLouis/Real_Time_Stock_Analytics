import yfinance as yf
import boto3
import json
import time
from datetime import datetime

# Initialize AWS clients
kinesis = boto3.client('kinesis', region_name='ap-southeast-1')

def fetch_and_send_stock_data():
    """Fetch ORCL stock data and send to Kinesis"""
    ticker = yf.Ticker("ORCL")
    
    while True:
        try:
            # Get current stock data
            info = ticker.info
            hist = ticker.history(period="1d", interval="1m")
            
            if not hist.empty:
                latest = hist.iloc[-1]
                
                stock_data = {
                    'ticker': 'ORCL',
                    'timestamp': int(datetime.now().timestamp()),
                    'price': float(latest['Close']),
                    'volume': int(latest['Volume']),
                    'high': float(latest['High']),
                    'low': float(latest['Low']),
                    'open': float(latest['Open'])
                }
                
                # Send to Kinesis
                kinesis.put_record(
                    StreamName='stock-data-stream',
                    Data=json.dumps(stock_data),
                    PartitionKey='ORCL'
                )
                
                print(f"Sent data: {stock_data}")
            
        except Exception as e:
            print(f"Error: {e}")
        
        # Wait 60 seconds before next fetch
        time.sleep(60)

if __name__ == "__main__":
    fetch_and_send_stock_data()