provider "aws" {
  region = var.aws_region
}

###### Elastic Serverless Forwarder
locals {
  # ESF YAML configuration content. Ref: https://www.elastic.co/guide/en/esf/master/aws-deploy-elastic-serverless-forwarder.html#sample-s3-config-file
  esf_config_file_content = yamlencode({
    inputs: [
      {
        type: "sqs"
        id: aws_sqs_queue.esf-queue.arn
        outputs: [
          {
            type: "elasticsearch"
            args: {
              cloud_id: var.cloud_id
              username: var.es_username
              password: var.es_password
              batch_max_actions: var.esf-es-max-batch-actions
              batch_max_bytes: var.esf-es-max-batch-bytes
            }
          }
        ]
    }
    ]
  })
}

data "external" "esf_lambda_loader" {
  program = ["${path.module}/esf-loader.sh"]

  query = {
    version          = "lambda-v1.8.0"
  }
}

module "esf-lambda-function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.esf-lambda-name
  handler       = "main_aws.lambda_handler"
  runtime       = "python3.9"
  build_in_docker   = true
  architectures       = ["x86_64"]
  docker_pip_cache          = true
  memory_size = var.memory_size
  timeout = var.timeout
  reserved_concurrent_executions = var.max_concurrency
  docker_additional_options = ["--platform", "linux/amd64"]
  source_path = data.external.esf_lambda_loader.result.package
  environment_variables = {
    S3_CONFIG_FILE: "s3://${aws_s3_bucket.esf-config-s3-bucket.bucket}/${aws_s3_object.esf-config-file-upload.key}"
    SQS_CONTINUE_URL: aws_sqs_queue.esf-continuing-queue.url
    SQS_REPLAY_URL: aws_sqs_queue.esf-replay-queue.url
    LOG_LEVEL: var.log_level
  }

  attach_policy_statements = true
  policy_statements = {
    s3_config = {
      effect    = "Allow",
      actions   = ["s3:GetObject"],
      resources = ["arn:aws:s3:::${aws_s3_bucket.esf-config-s3-bucket.bucket}/${aws_s3_object.esf-config-file-upload.key}"]
    },
    sqs_send = {
      effect    = "Allow",
      actions   = ["sqs:SendMessage"],
      resources = [aws_sqs_queue.esf-continuing-queue.arn, aws_sqs_queue.esf-replay-queue.arn]
    },
    sqs_receive = {
      effect    = "Allow",
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
      resources = [aws_sqs_queue.esf-continuing-queue.arn, aws_sqs_queue.esf-replay-queue.arn, aws_sqs_queue.esf-queue.arn]
    },
    ec2 = {
      effect    = "Allow",
      actions   = ["ec2:DescribeRegions"],
      resources = ["*"]
    }
  }
  depends_on = [
    data.external.esf_lambda_loader
  ]
}

resource "aws_lambda_event_source_mapping" "esf-source-sqs-event-mapping" {
  event_source_arn = aws_sqs_queue.esf-queue.arn
  function_name    = module.esf-lambda-function.lambda_function_arn
  batch_size = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_batch_window
}

resource "aws_lambda_event_source_mapping" "esf-continuining-sqs-event-mapping" {
  event_source_arn = aws_sqs_queue.esf-continuing-queue.arn
  function_name    = module.esf-lambda-function.lambda_function_arn
}

resource "aws_sqs_queue" "esf-continuing-queue" {
  name = "${var.esf-lambda-name}-continuining-queue"
  delay_seconds = 0
  sqs_managed_sse_enabled = true
  visibility_timeout_seconds = 910
}

resource "aws_sqs_queue" "esf-replay-queue" {
  name = "${var.esf-lambda-name}-replay-queue"
  delay_seconds = 0
  sqs_managed_sse_enabled = true
  visibility_timeout_seconds = 910
}

# ESF S3 Bucket to store the YAML config
resource "aws_s3_bucket" "esf-config-s3-bucket" {
  bucket = var.esf-config-bucket-name
  force_destroy = var.force_destroy //empty the bucket before deleting
}

# Upload the ESF YAML config to S3
resource "aws_s3_object" "esf-config-file-upload" {
  bucket = aws_s3_bucket.esf-config-s3-bucket.bucket
  key    = "elastic-serverless-forwarder.yaml"
  content = local.esf_config_file_content
}

###### Functionbeat
data "external" "lambda_loader" {
  program = ["${path.module}/functionbeat-loader.sh"]

  query = {
    version          = var.functionbeat_version
    config_file      = local_file.functionbeat_config.filename
    enabled_function = var.functionbeat_lambda_name
  }
}

resource "local_file" "functionbeat_config" {
  content = templatefile("${path.module}/functionbeat.yml.tftpl", {
    enabled_function_name  = var.functionbeat_lambda_name
    source_sqs_queue_arn = aws_sqs_queue.functionbeat-queue.arn
    cloud_id = var.cloud_id
    es_username = var.es_username
    es_password = var.es_password
  })
  filename = "${path.module}/functionbeat.yml"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"]
}

resource "aws_lambda_function" "functionbeat_lambda_function" {
  function_name    = var.functionbeat_lambda_name
  filename         = data.external.lambda_loader.result.filename
  source_code_hash = fileexists(data.external.lambda_loader.result.filename) ? filebase64sha256(data.external.lambda_loader.result.filename) : null
  handler          = "functionbeat-aws"
  runtime          = "go1.x"
  timeout          = var.timeout
  memory_size = var.memory_size
  reserved_concurrent_executions = var.max_concurrency

  environment {
    variables = {
      BEAT_STRICT_PERMS = "false"
      ENABLED_FUNCTIONS = var.functionbeat_lambda_name
      LOG_LEVEL         = var.log_level
    }
  }

  depends_on = [
    data.external.lambda_loader,
  ]
  role = aws_iam_role.iam_for_lambda.arn
}

resource "aws_lambda_event_source_mapping" "functionbeat-sqs-event-mapping" {
  event_source_arn = aws_sqs_queue.functionbeat-queue.arn
  function_name    = aws_lambda_function.functionbeat_lambda_function.arn
    batch_size = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_batch_window
}

##### Source SQS queue for ESF
resource "aws_sqs_queue" "esf-queue" {
  name = var.esf-sqs-queue-name
  visibility_timeout_seconds = 900
}

data "aws_iam_policy_document" "esf-sqs-queue-policy-document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.esf-queue.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.source-sns-topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "esf-queue-policy" {
  queue_url = aws_sqs_queue.esf-queue.id
  policy    = data.aws_iam_policy_document.esf-sqs-queue-policy-document.json
}

#### Source SQS queue for Functionbeat
resource "aws_sqs_queue" "functionbeat-queue" {
  name = var.functionbeat-sqs-queue-name
  visibility_timeout_seconds = 900
}

data "aws_iam_policy_document" "functionbeat-sqs-queue-policy-document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.functionbeat-queue.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.source-sns-topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "functionbeat-queue-policy" {
  queue_url = aws_sqs_queue.functionbeat-queue.id
  policy    = data.aws_iam_policy_document.functionbeat-sqs-queue-policy-document.json
}

#### Source SNS topic
resource "aws_sns_topic" "source-sns-topic" {
  name = var.source_sns_topic
}

resource "aws_sns_topic_subscription" "esf-sns-to-sqs-subscription" {
  topic_arn = aws_sns_topic.source-sns-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.esf-queue.arn
  //This ensures that no additional metadata is added by SNS, and the SQS queues receive the raw S3 notification event
  raw_message_delivery = true
}

resource "aws_sns_topic_subscription" "functionbeat-sns-to-sqs-subscription" {
  topic_arn = aws_sns_topic.source-sns-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.functionbeat-queue.arn
  //This ensures that no additional metadata is added by SNS, and the SQS queues receive the raw S3 notification event
  raw_message_delivery = true
}



