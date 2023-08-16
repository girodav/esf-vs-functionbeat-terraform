provider "aws" {
  region = var.aws_region
}

locals {
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
    ElasticServerlessForwarderS3ConfigFile = aws_s3_object.esf-config-file-upload.id
    ElasticServerlessForwarderSSMSecrets = ""
    ElasticServerlessForwarderKMSKeys = ""
    ElasticServerlessForwarderSQSEvents = ""
    ElasticServerlessForwarderS3SQSEvents = aws_sqs_queue.esf-queue.arn
    ElasticServerlessForwarderKinesisEvents = ""
    ElasticServerlessForwarderCloudWatchLogsEvents = ""
    ElasticServerlessForwarderS3Buckets = ""
    ElasticServerlessForwarderSecurityGroups = ""
    ElasticServerlessForwarderSubnets = ""
  }
}

resource "aws_s3_bucket" "esf-config-s3-bucket" {
  bucket = var.esf-config-bucket-name
}

resource "aws_s3_bucket" "source-bucket" {
  bucket = var.source_s3_bucket
}

resource "aws_s3_object" "esf-config-file-upload" {
  bucket = aws_s3_bucket.esf-config-s3-bucket.bucket
  key    = "elastic-serverless-forwarder.yaml"
  content = local.esf_config_file_content
}

# Create a new SQS queue for ESF
resource "aws_sqs_queue" "esf-queue" {
  name = var.esf-sqs-queue-name
  visibility_timeout_seconds = 900
}

data "aws_iam_policy_document" "sqs-queue-policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.esf-queue.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.source-bucket.arn]
    }
  }
}

# Allow the S3 bucket to write to the SQS queue
resource "aws_sqs_queue_policy" "test" {
  queue_url = aws_sqs_queue.esf-queue.id
  policy    = data.aws_iam_policy_document.sqs-queue-policy.json
}

# Create a new notification for the SQS queue when a new object is created and set the SQS as target
resource "aws_s3_bucket_notification" "bucket_notification-esf" {
  bucket = aws_s3_bucket.source-bucket.id
  queue {
    queue_arn = aws_sqs_queue.esf-queue.arn
    events    = ["s3:ObjectCreated:*"]
  }
}