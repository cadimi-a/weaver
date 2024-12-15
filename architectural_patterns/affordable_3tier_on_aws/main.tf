/***********************************************************************************************************************
 $                                               Presentation Logic Tier                                               $
 **********************************************************************************************************************/
locals {
  s3_origin_id = "${var.name_tag}-s3-origin"
}

resource "aws_cloudfront_distribution" "cf_distribution_to_s3" {
  origin {
    domain_name              = aws_s3_bucket.web_asset_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cf_origin_access_control.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "JP"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_control" "cf_origin_access_control" {
  name                              = var.name_tag
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 for Web Asset
resource "aws_s3_bucket" "web_asset_bucket" {
  bucket = "${var.name_tag}-assets"
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.web_asset_bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_cloudfront.json
}

data "aws_iam_policy_document" "allow_access_from_cloudfront" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.web_asset_bucket.arn,
      "${aws_s3_bucket.web_asset_bucket.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cf_distribution_to_s3.arn]
    }
  }
}

resource "aws_s3_object" "web_assets" {
  bucket = aws_s3_bucket.web_asset_bucket.bucket
  key    = "index.html"
  content_type = "text/html"

  source = "web_asset/index.html"
  etag = filemd5("web_asset/index.html")
}

# Cognito
resource "aws_cognito_user_pool" "cognito_user_pool" {
  name = "${var.name_tag}-user-pool"
}

resource "aws_cognito_user_pool_client" "cognito_user_pool_client" {
  name         = "${var.name_tag}-client"
  user_pool_id = aws_cognito_user_pool.cognito_user_pool.id

  explicit_auth_flows = ["USER_PASSWORD_AUTH"]
}

resource "aws_cognito_user_pool_domain" "example_domain" {
  domain       = var.name_tag
  user_pool_id = aws_cognito_user_pool.cognito_user_pool.id
}

/***********************************************************************************************************************
 $                                                 Business Logic Tier                                                 $
 **********************************************************************************************************************/
# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = var.name_tag
  depends_on = [
    aws_iam_role_policy_attachment.api_gw_policy_attachment,
  ]
}

resource "aws_api_gateway_resource" "api_gw_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "helloworld"
}

resource "aws_api_gateway_method" "api_gw_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.api_gw_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "api_gw_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.api_gw_resource.id
  http_method             = aws_api_gateway_method.api_gw_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn

  credentials = aws_iam_role.api_gw_role.arn
}

resource "aws_api_gateway_method_response" "api_gw_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.api_gw_resource.id
  http_method = aws_api_gateway_method.api_gw_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}


resource "aws_api_gateway_deployment" "api_gw_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.api_gw_integration,
    aws_cognito_user_pool_client.cognito_user_pool_client
  ]
}

resource "aws_api_gateway_stage" "api_gw_stage" {
  deployment_id = aws_api_gateway_deployment.api_gw_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}

# Authorizer for API Gateway
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                    = "${var.name_tag}-cognito-authorizer"
  type                    = "COGNITO_USER_POOLS"
  rest_api_id             = aws_api_gateway_rest_api.api.id
  provider_arns           = [aws_cognito_user_pool.cognito_user_pool.arn]
  identity_source         = "method.request.header.Authorization"
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

resource "aws_iam_policy" "api_gw_lambda_invoke_policy" {
  name = "api-gw-lambda-invoke"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "lambda:InvokeFunction",
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gw_policy_attachment" {
  role       = aws_iam_role.api_gw_role.name
  policy_arn = aws_iam_policy.api_gw_lambda_invoke_policy.arn
}

# Lambda
resource "aws_lambda_function" "lambda" {
  function_name = var.name_tag
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"

  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = aws_s3_object.hello_world_lambda_zip.key
  source_code_hash = data.archive_file.hello_world_lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.dynamodb_table.name
    }
  }

  depends_on = [
    data.archive_file.hello_world_lambda_zip,
    aws_iam_role_policy_attachment.basic_execution,
    aws_iam_role_policy_attachment.dynamodb_execution,
  ]
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

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "dynamodb_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# S3 Bucket for lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.name_tag
}

data "archive_file" "hello_world_lambda_zip" {
  type        = "zip"
  source_dir  = "lambda/hello_world"
  output_path = "hello_world_lambda.zip"
}

resource "aws_s3_object" "hello_world_lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = data.archive_file.hello_world_lambda_zip.output_path
  source = data.archive_file.hello_world_lambda_zip.output_path
  etag = filemd5(data.archive_file.hello_world_lambda_zip.output_path)
}

/***********************************************************************************************************************
 $                                                      Data Tier                                                      $
 **********************************************************************************************************************/

# DynamoDB
resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "Users"
  read_capacity  = 20
  write_capacity = 20

  hash_key = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = {
    Name = var.name_tag
  }
}
