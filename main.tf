provider "aws" {
  region = var.aws_region
}

locals {
  # ESF YAML configuration content. Ref: https://www.elastic.co/guide/en/esf/master/aws-deploy-elastic-serverless-forwarder.html#sample-s3-config-file
  esf_config_file_content = yamlencode({
    inputs: [
      {
        type: "s3-sqs"
        id: aws_sqs_queue.esf-queue.arn
        outputs: [
          {
            type: "elasticsearch"
            args: {
              cloud_id: var.cloud_id
              username: var.es_username
              password: var.es_password
            }
          }
        ]
    }
    ]
  })
}

##### Elastic Serverless Forwarder
# SAR Application definition, deployed through SAR. Ref: https://www.elastic.co/guide/en/esf/master/aws-deploy-elastic-serverless-forwarder.html#aws-serverless-forwarder-deploy-terraform
data "aws_serverlessapplicationrepository_application" "esf_sar" {
  application_id = var.esf_application_id
  semantic_version = var.esf_semantic_version
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "esf_cf_stack" {
  name             = var.esf-stack-name
  application_id   = data.aws_serverlessapplicationrepository_application.esf_sar.application_id
  semantic_version = data.aws_serverlessapplicationrepository_application.esf_sar.semantic_version
  capabilities     = data.aws_serverlessapplicationrepository_application.esf_sar.required_capabilities
parameters = {
    ElasticServerlessForwarderS3ConfigFile = "s3://${aws_s3_bucket.esf-config-s3-bucket.bucket}/${aws_s3_object.esf-config-file-upload.key}"
    ElasticServerlessForwarderSSMSecrets = ""
    ElasticServerlessForwarderKMSKeys = ""
    ElasticServerlessForwarderSQSEvents = ""
    ElasticServerlessForwarderS3SQSEvents = aws_sqs_queue.esf-queue.arn
    ElasticServerlessForwarderKinesisEvents = ""
    ElasticServerlessForwarderCloudWatchLogsEvents = ""
    ElasticServerlessForwarderS3Buckets = aws_s3_bucket.source-bucket.arn
    ElasticServerlessForwarderSecurityGroups = ""
    ElasticServerlessForwarderSubnets = ""
  }
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

##### Functionbeat
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
  timeout          = 900
  memory_size = 512

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
}


#### Source S3 Bucket definition
resource "aws_s3_bucket" "source-bucket" {
  bucket = var.source_s3_bucket
  force_destroy = var.force_destroy //empty the bucket before deleting
}

resource "aws_s3_bucket_notification" "bucket_notification-esf" {
  bucket = aws_s3_bucket.source-bucket.id
  topic {
    topic_arn = aws_sns_topic.source-sns-topic.arn
    events    = ["s3:ObjectCreated:*"]
  }
}


#### Source SQS queue for ESF
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

data "aws_iam_policy_document" "sns-policy-document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.source-sns-topic.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.source-bucket.arn]
    }
  }
}

resource "aws_sns_topic_policy" "sns-policy" {
  arn       = aws_sns_topic.source-sns-topic.arn
  policy    = data.aws_iam_policy_document.sns-policy-document.json
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



