provider "aws" {
  region = "us-east-1" # Update as per your requirement
}

# Create an S3 bucket for static content
resource "aws_s3_bucket" "static_content" {
  bucket = "my-static-content-bucket"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

# Create a DynamoDB table for storing messages
resource "aws_dynamodb_table" "messages" {
  name         = "MessagesTable"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "MessageID"
    type = "S"
  }

  hash_key = "MessageID"
}

# Create an API Gateway
resource "aws_apigatewayv2_api" "websocket_api" {
  name          = "websocket-api"
  protocol_type = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "connect_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_connect.id}"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_default.id}"
}

# Lambda Functions
resource "aws_lambda_function" "lambda_connect" {
  filename         = "lambda_connect.zip" # Package your Lambda code
  function_name    = "ConnectHandler"
  handler          = "index.handler"
  runtime          = "nodejs18.x" # Adjust runtime as needed

  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "lambda_default" {
  filename         = "lambda_default.zip" # Package your Lambda code
  function_name    = "DefaultHandler"
  handler          = "index.handler"
  runtime          = "nodejs18.x" # Adjust runtime as needed

  role             = aws_iam_role.lambda_exec.arn
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

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

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
