###### Functionbeat
data "external" "functionbeat_lambda_loader" {
  count                    = length(data.aws_sqs_queue.functionbeat-queue)
  program = ["${path.module}/functionbeat-loader.sh"]

  query = {
    version          = var.functionbeat_version
    config_file      = local_file.functionbeat_config.filename
    enabled_function = join(var.functionbeat_lambda_name, count.index)
  }
}

resource "local_file" "functionbeat_config" {
  content = templatefile("${path.module}/functionbeat.yml.tftpl", {
    for_each = toset (data.aws_sqs_queue.functionbeat-queue)
    enabled_function_name = var.functionbeat_lambda_name
    source_sqs_queue_arn  = each.value.arns
    cloud_id              = var.cloud_id
    es_username           = var.es_username
    es_password           = var.es_password
    bulk_max_size         = var.es-max-batch-actions
    log_level             = lower(var.log_level)
  })
  filename = "${path.module}/functionbeat.yml"
}

data "aws_iam_policy_document" "functionbeat_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "functionbeat_iam_for_lambda" {
  name                = "functionbeat_iam_for_lambda"
  assume_role_policy  = data.aws_iam_policy_document.functionbeat_assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"]
}

resource "aws_lambda_function" "functionbeat_lambda_function" {
  for_each = toset(data.aws_sqs_queue.functionbeat-queue)
  function_name                  = join(var.functionbeat_lambda_name, each.value.name)
  filename                       = data.external.functionbeat_lambda_loader.result.filename
  source_code_hash               = fileexists(data.external.functionbeat_lambda_loader.result.filename) ? filebase64sha256(data.external.functionbeat_lambda_loader.result.filename) : null
  handler                        = "functionbeat-aws"
  runtime                        = "go1.x"
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = var.max_concurrency

  environment {
    variables = {
      BEAT_STRICT_PERMS = "false"
      ENABLED_FUNCTIONS = var.functionbeat_lambda_name
      LOG_LEVEL         = var.log_level
    }
  }

  depends_on = [
    data.external.functionbeat_lambda_loader,
  ]
  role = aws_iam_role.functionbeat_iam_for_lambda.arn
}

resource "aws_lambda_event_source_mapping" "functionbeat-sqs-event-mapping" {
  for_each = toset(data.aws_sqs_queue.functionbeat-queue)
  event_source_arn                   = each.value
  function_name                      = join(var.functionbeat_lambda_name, each.value.name)
  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_batch_window
  enabled                            = var.functionbeat_enabled
}
