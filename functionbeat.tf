###### Functionbeat
data "external" "functionbeat_lambda_loader" {
  program = ["${path.module}/functionbeat-loader.sh"]

  query = {
    version          = var.functionbeat_version
    config_file      = local_file.functionbeat_config.filename
    enabled_function = var.functionbeat_lambda_name
  }
}

resource "local_file" "functionbeat_config" {
  content = templatefile("${path.module}/functionbeat.yml.tftpl", {
    enabled_function_name = var.functionbeat_lambda_name
    source_sqs_queue_arn  = aws_sqs_queue.functionbeat-queue.arn
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
  function_name                  = var.functionbeat_lambda_name
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
  event_source_arn                   = aws_sqs_queue.functionbeat-queue.arn
  function_name                      = aws_lambda_function.functionbeat_lambda_function.arn
  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_batch_window
  enabled                            = var.functionbeat_enabled
}
