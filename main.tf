# S3 Buckets
resource "aws_s3_bucket" "raw_data" {
  bucket        = "stock-analytics-raw-data-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket" "athena_results" {
  bucket        = "stock-analytics-athena-results-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# DynamoDB Table
resource "aws_dynamodb_table" "stock_data" {
  name           = "stock-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ticker"
  range_key      = "timestamp"

  attribute {
    name = "ticker"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }
}

# Kinesis Data Stream
resource "aws_kinesis_stream" "stock_stream" {
  name        = "stock-data-stream"
  shard_count = 1
}

# SNS Topic
resource "aws_sns_topic" "stock_alerts" {
  name = "stock-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.stock_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_role" {
  name = "stock-analytics-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "stock-analytics-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListStreams"
        ]
        Resource = aws_kinesis_stream.stock_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.raw_data.arn}/*",
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.stock_data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.stock_alerts.arn
      }
    ]
  })
}

# Data Processing Lambda
resource "aws_lambda_function" "data_processor" {
  filename         = "data_processor.zip"
  function_name    = "stock-data-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      RAW_DATA_BUCKET = aws_s3_bucket.raw_data.bucket
    }
  }

  depends_on = [data.archive_file.data_processor_zip]
}

resource "aws_lambda_event_source_mapping" "kinesis_trigger" {
  event_source_arn  = aws_kinesis_stream.stock_stream.arn
  function_name     = aws_lambda_function.data_processor.arn
  starting_position = "LATEST"
}

# Trend Analysis Lambda
resource "aws_lambda_function" "trend_analyzer" {
  filename         = "trend_analyzer.zip"
  function_name    = "stock-trend-analyzer"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.stock_alerts.arn
    }
  }

  depends_on = [data.archive_file.trend_analyzer_zip]
}

resource "aws_cloudwatch_event_rule" "trend_schedule" {
  name                = "stock-trend-schedule"
  description         = "Trigger trend analysis every minute for faster alerts"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.trend_schedule.name
  target_id = "TrendAnalyzerTarget"
  arn       = aws_lambda_function.trend_analyzer.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trend_analyzer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trend_schedule.arn
}

# Data Glue Catalog
resource "aws_glue_catalog_database" "stock_database" {
  name = "stock_analytics_db"
}

resource "aws_iam_role" "glue_role" {
  name = "stock-analytics-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_policy" {
  name = "glue-s3-policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_data.arn,
          "${aws_s3_bucket.raw_data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_glue_crawler" "stock_crawler" {
  database_name = aws_glue_catalog_database.stock_database.name
  name          = "stock-data-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.raw_data.bucket}/stock-data/"
  }

  schedule = "cron(0 */6 * * ? *)"
}

# Archive files for Lambda functions
data "archive_file" "data_processor_zip" {
  type        = "zip"
  output_path = "data_processor.zip"
  source_dir  = "lambda/data_processor"
}

data "archive_file" "trend_analyzer_zip" {
  type        = "zip"
  output_path = "trend_analyzer.zip"
  source_dir  = "lambda/trend_analyzer"
}

# VPC and Networking
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "stock-analytics-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "stock-analytics-public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "stock-analytics-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "stock-analytics-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2" {
  name_prefix = "stock-analytics-ec2-"
  vpc_id      = aws_vpc.main.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "stock-analytics-ec2-sg"
  }
}

# EC2 Instance for Data Ingestion
resource "aws_instance" "data_ingestion" {
  ami           = "ami-0df7a207adb9748c7"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  user_data = base64encode(file("ec2_userdata.sh"))
  
  tags = {
    Name = "stock-data-ingestion"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "stock-ingestion-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_kinesis_policy" {
  name = "ec2-kinesis-policy"
  role = aws_iam_role.ec2_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.stock_stream.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "stock-ingestion-profile"
  role = aws_iam_role.ec2_role.name
}