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
}

# Upload the ESF YAML config to S3
resource "aws_s3_object" "esf-config-file-upload" {
  bucket = aws_s3_bucket.esf-config-s3-bucket.bucket
  key    = "elastic-serverless-forwarder.yaml"
  content = local.esf_config_file_content
}


#### Source S3 Bucket definition
resource "aws_s3_bucket" "source-bucket" {
  bucket = var.source_s3_bucket
}

resource "aws_s3_bucket_notification" "bucket_notification-esf" {
  bucket = aws_s3_bucket.source-bucket.id
  topic {
    topic_arn = aws_sns_topic.s3-upload-topic.arn
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
      values   = [aws_sns_topic.s3-upload-topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "esf-queue-policy" {
  queue_url = aws_sqs_queue.esf-queue.id
  policy    = data.aws_iam_policy_document.esf-sqs-queue-policy-document.json
}

#### Source SNS topic
resource "aws_sns_topic" "s3-upload-topic" {
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
    resources = [aws_sns_topic.s3-upload-topic.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.source-bucket.arn]
    }
  }
}

resource "aws_sns_topic_policy" "sns-policy" {
  arn       = aws_sns_topic.s3-upload-topic.arn
  policy    = data.aws_iam_policy_document.sns-policy-document.json
}

resource "aws_sns_topic_subscription" "esf-sns-to-sqs-subscription" {
  topic_arn = aws_sns_topic.s3-upload-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.esf-queue.arn
  //This ensures that no additional metadata is added by SNS, and the SQS queues receive the raw S3 notification event
  raw_message_delivery = true
}



