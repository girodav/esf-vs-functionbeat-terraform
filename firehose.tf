###### Firehose
data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "firehose_role" {
  name               = format("firehose-%s", var.firehose-delivery-stream-name)
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

resource "aws_s3_bucket" "firehose_bucket" {
  bucket        = var.firehose-bucket-name
  force_destroy = var.force_destroy //empty the bucket before deleting
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_delivery_stream" {
  destination = "http_endpoint"
  name        = var.firehose-delivery-stream-name

  http_endpoint_configuration {
    url                = var.firehose-es_url
    name               = "Elastic"
    access_key         = var.firehose-es_apikey
    buffering_size     = 15
    buffering_interval = 600
    role_arn           = aws_iam_role.firehose_role.arn
    s3_backup_mode     = "FailedDataOnly"

    s3_configuration {
      role_arn           = aws_iam_role.firehose_role.arn
      bucket_arn         = aws_s3_bucket.firehose_bucket.arn
      buffering_size     = 10
      buffering_interval = 400
      compression_format = "GZIP"
    }

    request_configuration {
      content_encoding = "GZIP"
    }
  }
}