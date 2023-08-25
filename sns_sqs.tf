##### Source SQS queue for ESF
resource "aws_sqs_queue" "esf-queue" {
  name                       = var.esf-sqs-queue-name
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
  name                       = var.functionbeat-sqs-queue-name
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
  count                = var.esf_enabled ? 1 : 0
}

resource "aws_sns_topic_subscription" "functionbeat-sns-to-sqs-subscription" {
  topic_arn = aws_sns_topic.source-sns-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.functionbeat-queue.arn
  //This ensures that no additional metadata is added by SNS, and the SQS queues receive the raw S3 notification event
  raw_message_delivery = true
  count                = var.functionbeat_enabled ? 1 : 0
}