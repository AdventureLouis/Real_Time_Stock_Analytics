output "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  value       = aws_kinesis_stream.stock_stream.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.stock_alerts.arn
}

output "raw_data_bucket" {
  description = "Name of the S3 bucket for raw data"
  value       = aws_s3_bucket.raw_data.bucket
}

output "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena results"
  value       = aws_s3_bucket.athena_results.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.stock_data.name
}