# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = var.name_tag
  depends_on = [
    aws_iam_role_policy_attachment.api_gw_policy_attachment,
  ]
}

resource "aws_api_gateway_resource" "dynamodb_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "dynamodb"
}

resource "aws_api_gateway_method" "api_gw_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.dynamodb_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_gw_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.dynamodb_resource.id
  http_method             = aws_api_gateway_method.api_gw_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.region}:dynamodb:action/PutItem"
  passthrough_behavior    = "WHEN_NO_TEMPLATES"

  credentials = aws_iam_role.api_gw_role.arn

  request_templates = {
    "application/json" = file("api_gw_mapping.template")
  }
}

resource "aws_api_gateway_method_response" "api_gw_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamodb_resource.id
  http_method = aws_api_gateway_method.api_gw_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamodb_resource.id
  http_method = aws_api_gateway_method.api_gw_method.http_method
  status_code = aws_api_gateway_method_response.api_gw_method_response.status_code
}


resource "aws_api_gateway_deployment" "api_gw_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [aws_api_gateway_integration.api_gw_integration]
}

resource "aws_api_gateway_stage" "api_gw_stage" {
  deployment_id = aws_api_gateway_deployment.api_gw_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}

# DynamoDB
resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "Comments"
  read_capacity  = 20
  write_capacity = 20

  hash_key  = "commentId"

  attribute {
    name = "commentId"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = {
    Name = var.name_tag
  }
}

# S3 Bucket for Lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.name_tag
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda.zip"
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "lambda.zip"
  source = data.archive_file.lambda_zip.output_path
  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

# Lambda
resource "aws_lambda_function" "lambda" {
  function_name = var.name_tag
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"

  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = aws_s3_object.lambda_zip.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.dynamodb_table.name
    }
  }

  depends_on = [
    data.archive_file.lambda_zip,
    aws_iam_role_policy_attachment.basic_execution_role,
    aws_iam_role_policy_attachment.lambda_dynamodb_stream_policy_attachment,
  ]
}

resource "aws_lambda_event_source_mapping" "dynamodb_lambda_mapping" {
  event_source_arn  = aws_dynamodb_table.dynamodb_table.stream_arn
  function_name     = aws_lambda_function.lambda.arn
  starting_position = "TRIM_HORIZON"
}

# IAM for API Gateway
resource "aws_iam_role" "api_gw_role" {
  name = "api-gw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "apigateway.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "api_gw_dynamodb_access" {
  name = "api-gw-dynamodb-access"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:DeleteItem",
          "dynamodb:Scan"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gw_policy_attachment" {
  role       = aws_iam_role.api_gw_role.name
  policy_arn = aws_iam_policy.api_gw_dynamodb_access.arn
}

# IAM for Lambda
resource "aws_iam_role" "lambda_role" {
  name        = "lambda-execution-role"
  description = "Lambda Execution Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_dynamodb_stream_policy" {
  name = "lambda-dynamodb-stream-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ],
        "Resource" : "${aws_dynamodb_table.dynamodb_table.arn}/stream/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_stream_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_stream_policy.arn
}