data "aws_sqs_queue" "esf-queue" {
  for_each = { for k, v in var.sqs_esf_names : k => v if length(var.sqs_esf_arns)==0 }
  name = each.value
} 


locals {
  list_s3_names = join(", ", [for s3names in var.s3_esf_names : format("arn:aws:s3:::%s", s3names)])
  get_s3_names = join(", ", [for s3names in var.s3_esf_names : format("arn:aws:s3:::%s/*", s3names)])

  policy_statements1 = merge(
  {s3_config = {
      effect    = "Allow",
      actions   = ["s3:GetObject"],
      resources = ["arn:aws:s3:::${aws_s3_bucket.esf-config-s3-bucket.bucket}/${data.aws_s3_object.esf-config-file-upload.key}"]
    },
    sqs_send = {
      effect    = "Allow",
      actions   = ["sqs:SendMessage"],
      resources = [aws_sqs_queue.esf-continuing-queue.arn, aws_sqs_queue.esf-replay-queue.arn]
    },
    sqs_receive = {
      effect    = "Allow",
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
      resources = [aws_sqs_queue.esf-continuing-queue.arn, aws_sqs_queue.esf-replay-queue.arn]
    },
    ec2 = {
      effect    = "Allow",
      actions   = ["ec2:DescribeRegions"],
      resources = ["*"]
    }
    }, var.s3_esf_names != null ? {
    s3_list = {
      effect    = "Allow",
      actions   = ["s3:ListBucket"],
      resources = local.list_s3_names # list("arn:aws:s3:::bucket1", "arn:aws:s3:::bucket2")

    },
    s3_get_object = {
      effect    = "Allow",
      actions   = ["s3:GetObject"],
      resources = local.get_s3_names # list("arn:aws:s3:::bucket1/*", "arn:aws:s3:::bucket2/*")
    }
    } : {})
    
    policy_statements = merge( local.policy_statements1 , var.cloudwatchlogs_esf_names != null ? {
    ec2 = {
      for_each = var.cloudwatchlogs_esf_names
      effect    = "Allow",
      actions   = ["ec2:DescribeRegions"],
      resources = ["*"]
    }}: {})
}
###### Elastic Serverless Forwarder
# locals {
#   # ESF YAML configuration content. Ref: https://www.elastic.co/guide/en/esf/master/aws-deploy-elastic-serverless-forwarder.html#sample-s3-config-file
#   esf_config_file_content = yamlencode({
#     inputs : [
#       {

#         type : "sqs"
#         id : aws_sqs_queue.esf-queue.arn
#         outputs : [
#           {
#             type : "elasticsearch"
#             args : {
#               cloud_id : var.cloud_id
#               username : var.es_username
#               password : var.es_password
#               es_datastream_name : "logs-fwdr.test-default"
#               batch_max_actions : var.es-max-batch-actions
#               batch_max_bytes : var.esf-es-max-batch-bytes
#             }
#           }
#         ]
#       }
#     ]
#   })
# }

data "external" "esf_lambda_loader" {
  program = ["${path.module}/esf-loader.sh"]

  query = {
    version = "lambda-v1.8.0"
  }
}

module "esf-lambda-function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "6.0.0"

  function_name                  = var.esf-lambda-name
  handler                        = "main_aws.lambda_handler"
  runtime                        = "python3.9"
  build_in_docker                = true
  architectures                  = ["x86_64"]
  docker_pip_cache               = true
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.max_concurrency
  docker_additional_options      = ["--platform", "linux/amd64"]
  source_path                    = data.external.esf_lambda_loader.result.package
  environment_variables = {
    S3_CONFIG_FILE : "s3://${aws_s3_bucket.esf-config-s3-bucket.bucket}/${data.aws_s3_object.esf-config-file-upload.key}"
    SQS_CONTINUE_URL : aws_sqs_queue.esf-continuing-queue.url
    SQS_REPLAY_URL : aws_sqs_queue.esf-replay-queue.url
    LOG_LEVEL : var.log_level
  }
  attach_policies = true
  policies        = [
    "arn:aws:iam::aws:policy/AWSLambdaSQSQueueExecutionRole",
  ]

  attach_policy_statements = true
  policy_statements = local.policy_statements
    
  depends_on = [
    data.external.esf_lambda_loader
  ]

  use_existing_cloudwatch_log_group = true
}

resource "aws_lambda_event_source_mapping" "esf-source-sqs-event-mapping" {
  for_each = toset(data.aws_sqs_queue.esf-queue)
  event_source_arn                   = each.value.arn
  function_name                      = module.esf-lambda-function.lambda_function_arn
  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_batch_window
  enabled                            = var.esf_enabled
}

resource "aws_lambda_event_source_mapping" "esf-continuining-sqs-event-mapping" {
  event_source_arn = aws_sqs_queue.esf-continuing-queue.arn
  function_name    = module.esf-lambda-function.lambda_function_arn
}

resource "aws_sqs_queue" "esf-continuing-queue" {
  name                       = "${var.esf-lambda-name}-continuining-queue"
  delay_seconds              = 0
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 910
}

resource "aws_sqs_queue" "esf-replay-queue" {
  name                       = "${var.esf-lambda-name}-replay-queue"
  delay_seconds              = 0
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 910
}

# ESF S3 Bucket to store the YAML config
resource "aws_s3_bucket" "esf-config-s3-bucket" {
  bucket        = var.esf-config-bucket-name
  force_destroy = var.force_destroy //empty the bucket before deleting
}

# Check the ESF YAML config inside S3
data "aws_s3_object" "esf-config-file-upload" {
  bucket  = aws_s3_bucket.esf-config-s3-bucket.bucket
  key     = "elastic-serverless-forwarder.yaml"
}

