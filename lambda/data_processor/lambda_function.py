import json
import boto3
import base64
from datetime import datetime
from decimal import Decimal
import os

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    table = dynamodb.Table('stock-data')
    
    for record in event['Records']:
        # Decode Kinesis data
        payload = base64.b64decode(record['kinesis']['data'])
        data = json.loads(payload)
        
        # Store raw data in S3
        timestamp = datetime.now().strftime('%Y/%m/%d/%H')
        s3_key = f"stock-data/{timestamp}/{data['ticker']}_{record['kinesis']['sequenceNumber']}.json"
        
        s3.put_object(
            Bucket=os.environ.get('RAW_DATA_BUCKET', 'stock-analytics-raw-data'),
            Key=s3_key,
            Body=json.dumps(data)
        )
        
        # Store processed data in DynamoDB
        table.put_item(
            Item={
                'ticker': data['ticker'],
                'timestamp': int(data['timestamp']),
                'price': Decimal(str(data['price'])),
                'close': Decimal(str(data.get('close', data['price']))),
                'volume': int(data.get('volume', 0)),
                'high': Decimal(str(data.get('high', data['price']))),
                'low': Decimal(str(data.get('low', data['price']))),
                'open': Decimal(str(data.get('open', data['price'])))
            }
        )
    
    return {'statusCode': 200, 'body': json.dumps('Data processed successfully')}