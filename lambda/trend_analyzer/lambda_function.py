import json
import boto3
from datetime import datetime, timedelta
from decimal import Decimal
import os

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

def lambda_handler(event, context):
    table = dynamodb.Table('stock-data')
    
    # Get recent ORCL data
    end_time = int(datetime.now().timestamp())
    start_time = int((datetime.now() - timedelta(hours=2)).timestamp())
    
    try:
        response = table.query(
            KeyConditionExpression='ticker = :ticker AND #ts BETWEEN :start AND :end',
            ExpressionAttributeNames={'#ts': 'timestamp'},
            ExpressionAttributeValues={
                ':ticker': 'ORCL',
                ':start': start_time,
                ':end': end_time
            },
            ScanIndexForward=True
        )
        
        items = response['Items']
        print(f"Found {len(items)} data points")
        
        if len(items) < 5:
            # Send test alert if insufficient data
            test_message = f"""
ORCL Pipeline Test Alert

Status: Pipeline is running
Data points found: {len(items)}
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}

This confirms your email alerts are working!
            """
            
            sns.publish(
                TopicArn=os.environ['SNS_TOPIC_ARN'],
                Message=test_message,
                Subject='ORCL Pipeline Test - Email Working!'
            )
            return {'statusCode': 200, 'body': 'Test alert sent'}
        
        # Calculate moving averages
        prices = [float(item['price']) for item in items]
        current_price = prices[-1]
        
        # Calculate SMA-5 and SMA-20 (or available data)
        sma_5 = sum(prices[-5:]) / min(5, len(prices))
        sma_20 = sum(prices[-20:]) / min(20, len(prices)) if len(prices) >= 10 else sum(prices) / len(prices)
        
        # Generate signal based on price movement and SMAs
        signal = None
        if len(prices) >= 3:
            price_trend = prices[-1] - prices[-3]
            if sma_5 > sma_20 and price_trend > 0:
                signal = 'BUY'
            elif sma_5 < sma_20 and price_trend < 0:
                signal = 'SELL'
            elif abs(price_trend) > 1.0:  # Significant price movement
                signal = 'BUY' if price_trend > 0 else 'SELL'
        
        # Send alert
        if signal:
            message = f"""
🚨 ORCL STOCK ALERT: {signal} SIGNAL 🚨

Current Price: ${current_price:.2f}
SMA-5: ${sma_5:.2f}
SMA-20: ${sma_20:.2f}
Data Points: {len(items)}

Signal Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}

Action: Consider {signal.lower()}ing ORCL stock
            """
            
            sns.publish(
                TopicArn=os.environ['SNS_TOPIC_ARN'],
                Message=message,
                Subject=f'🚨 ORCL {signal} SIGNAL - ${current_price:.2f}'
            )
            
            return {'statusCode': 200, 'body': f'{signal} signal sent'}
        else:
            # Send periodic update every hour
            message = f"""
ORCL Stock Update

Current Price: ${current_price:.2f}
SMA-5: ${sma_5:.2f}
SMA-20: ${sma_20:.2f}
Data Points: {len(items)}

Status: Monitoring for signals...
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}
            """
            
            sns.publish(
                TopicArn=os.environ['SNS_TOPIC_ARN'],
                Message=message,
                Subject=f'ORCL Update - ${current_price:.2f}'
            )
            
            return {'statusCode': 200, 'body': 'Update sent'}
            
    except Exception as e:
        print(f"Error: {e}")
        # Send error alert
        sns.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message=f"ORCL Pipeline Error: {str(e)}\nTime: {datetime.now()}",
            Subject='ORCL Pipeline Error Alert'
        )
        return {'statusCode': 500, 'body': f'Error: {e}'}