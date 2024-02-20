##### Source SQS queue for ESF

data "aws_sqs_queue" "esf-queue" {
  for_each = toset(var.sqs_esf_names)
  name = each.value
} 

# resource "aws_sqs_queue" "esf-queue" {
#   name                       = var.esf-sqs-queue-name
#   visibility_timeout_seconds = 900
# }

 
data "aws_iam_policy_document" "esf-sqs-queue-policy-document" {
  for_each = toset(resource.aws_sns_topic.source-sns-topic)
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [each.value.tags.sqs_esf_arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [each.value.ar]
    }
  }
}

resource "aws_sqs_queue_policy" "esf-queue-policy" {
  count = length(data.aws_sqs_queue.esf-queue)
  queue_url = data.aws_sqs_queue.esf-queue[count.index].id
  policy    = data.aws_iam_policy_document.esf-sqs-queue-policy-document[count.index].json
}

#### Source SQS queue for Functionbeat

data "aws_sqs_queue" "functionbeat-queue" {
  for_each = toset(var.sqs_functionbeat_names)
  name = each.value
} 


# resource "aws_sqs_queue" "functionbeat-queue" {
#   name                       = var.functionbeat-sqs-queue-name
#   visibility_timeout_seconds = 900
# }

data "aws_iam_policy_document" "functionbeat-sqs-queue-policy-document" {
  for_each = toset(resource.aws_sns_topic.source-sns-topic)
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [each.value.tags.sqs_functionbeat_arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [each.value.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "functionbeat-queue-policy" {
  count = length(data.aws_sqs_queue.functionbeat-queue)
  queue_url = data.aws_sqs_queue.functionbeat-queue[count.index].id
  policy    = data.aws_iam_policy_document.functionbeat-sqs-queue-policy-document[count.index].json
}

#### Source SNS topic
resource "aws_sns_topic" "source-sns-topic" {
  count = length(data.aws_sqs_queue.esf-queue)
  name = var.source_sns_topic
  tags = {
    sqs_functionbeat_arn = data.aws_sqs_queue.functionbeat-queue[count.index].arn
    sqs_esf_arn =  data.aws_sqs_queue.esf-queue[count.index].arn
  }
}

resource "aws_sns_topic_subscription" "esf-sns-to-sqs-subscription" {
  count = var.esf_enabled ? length(resource.aws_sns_topic.source-sns-topic) :0 
  topic_arn = resource.aws_sns_topic.source-sns-topic[count.index].arn
  protocol  = "sqs"
  endpoint  = resource.aws_sns_topic.source-sns-topic[count.index].tags.sqs_esf_arn
  //This ensures that no additional metadata is added by SNS, and the SQS queues receive the raw S3 notification event
  raw_message_delivery = true
}

resource "aws_sns_topic_subscription" "functionbeat-sns-to-sqs-subscription" {
  count = var.functionbeat_enabled ? length(resource.aws_sns_topic.source-sns-topic) : 0
  topic_arn = resource.aws_sns_topic.source-sns-topic[count.index].arn
  protocol  = "sqs"
  endpoint  = resource.aws_sns_topic.source-sns-topic[count.index].tags.sqs_functionbeat_arn
  //This ensures that no additional metadata is added by SNS, and the SQS queues receive the raw S3 notification event
  raw_message_delivery = true
}