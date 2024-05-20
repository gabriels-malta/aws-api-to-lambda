terraform {
  required_providers {
    aws = {
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

resource "aws_dynamodb_table" "transactions" {
  name     = "Transctions"
  hash_key = "Id"
  attribute {
    name = "Id"
    type = "S"
  }

  billing_mode = "PAY_PER_REQUEST"
}

resource "aws_iam_role" "forLambda" {
  name                = "lambda_basic_execution"
  assume_role_policy  = data.aws_iam_policy_document.lambda.json
  managed_policy_arns = [data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn]
  inline_policy {
    name = "Custom_WriteToDynamoDB"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "dynamodb:PutItem",
          ]
          Effect   = "Allow"
          Resource = aws_dynamodb_table.transactions.arn
        },
      ]
    })
  }
}

resource "aws_cloudwatch_log_group" "saveRequestFromApi" {
  name              = "/aws/lambda/${aws_lambda_function.saveRequestFromApi.function_name}"
  retention_in_days = 1
}

resource "aws_lambda_function" "saveRequestFromApi" {
  depends_on = [
    aws_iam_role.forLambda,
    aws_cloudwatch_log_group.saveRequestFromApi
  ]
  filename         = "function.zip"
  function_name    = "fxSaveRequestFromApi"
  role             = aws_iam_role.forLambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "nodejs20.x"
  logging_config {
    log_format = "JSON"
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name = "punk records"
}
resource "aws_api_gateway_resource" "labPhase" {
  path_part   = "lab-phase"
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api.id
}
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.labPhase.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_lambda_permission" "apigw_lambda" {
  depends_on    = [aws_lambda_function.saveRequestFromApi]
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.saveRequestFromApi.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.labPhase.path}"
}
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.labPhase.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.labPhase.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
}
