data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  name = "AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy" "AWSLambdaRole" {
  name = "AWSLambdaRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "../code/index.mjs"
  output_path = "function.zip"
}
