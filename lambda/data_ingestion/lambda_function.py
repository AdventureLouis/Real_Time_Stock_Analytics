import json
import boto3
import yfinance as yf
from datetime import datetime

kinesis = boto3.client('kinesis')

def lambda_handler(event, context):
    try:
        ticker = yf.Ticker("ORCL")
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
            
            kinesis.put_record(
                StreamName='stock-data-stream',
                Data=json.dumps(stock_data),
                PartitionKey='ORCL'
            )
            
            return {'statusCode': 200, 'body': json.dumps('Data sent successfully')}
    
    except Exception as e:
        print(f"Error: {e}")
        return {'statusCode': 500, 'body': json.dumps(f'Error: {str(e)}')}