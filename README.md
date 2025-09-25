# Real-Time Stock Analytics Pipeline

A comprehensive AWS-based real-time stock market data analytics pipeline that monitors ORCL stock and sends buy/sell signal alerts via email.

## Architecture

- **Data Ingestion**: Python script with yfinance → Kinesis Data Streams
- **Data Processing**: Lambda function → S3 (raw) + DynamoDB (processed)
- **Data Cataloging**: AWS Glue Crawler → Glue Catalog
- **Analytics**: AWS Athena queries on structured data
- **Real-time Analysis**: Lambda function calculating SMA-5/SMA-20 → SNS alerts

## Deployment

1. **Setup Variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your email
   ```

2. **Deploy Infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve
   ```

3. **Confirm SNS Subscription**:
   - Check your email and confirm the SNS subscription
   - EC2 instance will automatically install dependencies and start data ingestion

## Management Commands

**Plan Changes**:
```bash
terraform plan
```

**Apply Changes**:
```bash
terraform apply -auto-approve
```

**Destroy Infrastructure**:
```bash
terraform destroy -auto-approve
```

**View Outputs**:
```bash
terraform output
```

## Components

### Lambda Functions
- **data_processor**: Processes Kinesis stream data
- **trend_analyzer**: Analyzes trends and sends alerts (runs every 5 minutes)

### Storage
- **S3**: Raw data storage and Athena results
- **DynamoDB**: Real-time processed data lookups

### Analytics
- **Glue Crawler**: Catalogs S3 data every 6 hours
- **Athena**: SQL queries on cataloged data

### Alerts
- **SNS**: Email notifications for buy/sell signals

## Buy/Sell Signal Logic

- **BUY Signal**: SMA-5 crosses above SMA-20
- **SELL Signal**: SMA-5 crosses below SMA-20

## Monitoring

The pipeline monitors ORCL stock and sends email alerts when trading signals are detected based on moving average crossovers.

## Viewing Buy/Sell Signals

**Email Alerts**: Check your email for instant notifications

**CloudWatch Logs**:
```bash
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/stock-trend-analyzer"
```

**DynamoDB Data**:
```bash
aws dynamodb scan --table-name stock-data --region ap-southeast-1
```

**Video Demo**

Uploading main.mp4…

