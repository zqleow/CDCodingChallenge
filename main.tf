# Terraform provider configuration
provider "aws" {
  region = "ap-southeast-1"
}

# Define the IAM Role for the Lambda Function
resource "aws_iam_role" "lambda_role" {
  name               = "lambda-s3-dynamo-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach IAM Policy to the Lambda Role (S3 Full Access)
resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Attach IAM Policy to the Lambda Role (DynamoDB Full Access)
resource "aws_iam_role_policy_attachment" "lambda_dynamo_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Create the S3 Bucket to store certificates
resource "aws_s3_bucket" "certificate_bucket" {
  bucket = "my-certificates-bucket-2024-12-31"
}


# S3 Bucket Versioning Configuration (correct usage with versioning_configuration block)
resource "aws_s3_bucket_versioning" "certificate_bucket_versioning" {
  bucket = aws_s3_bucket.certificate_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Define Lambda Function
resource "aws_lambda_function" "process_certificate" {
  function_name = "process-certificate-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"  # Modify as per your Lambda handler function
  runtime       = "nodejs18.x"     # Correct runtime version
  filename      = "lambda_function.zip"     # Specify your Lambda function code source
}

# Attach IAM Execution Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" # Lambda execution policy for CloudWatch Logs
}

# DynamoDB Table for storing certificates
resource "aws_dynamodb_table" "certificates_table" {
  name         = "CertificatesTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "certificate_id"
  attribute {
    name = "certificate_id"
    type = "S"
  }

  # Enable TTL (Time to Live) for automatic expiration
  ttl {
    enabled = true
    attribute_name = "expiration_time"
  }

  tags = {
    Environment = "Production"
  }
}

# Create an IAM policy for Lambda access to S3 and DynamoDB
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-s3-dynamo-policy"
  description = "Policy for Lambda to access S3 and DynamoDB"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.certificate_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.certificate_bucket.bucket}/*"
        ]
      },
      {
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
        Effect   = "Allow"
        Resource = "${aws_dynamodb_table.certificates_table.arn}"
      }
    ]
  })
}

# Attach the custom IAM policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_custom_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}
