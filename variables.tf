# Secrets
variable "functionbeat-cloud_id" {
  description = "Elasticsearch cloud_id for Functionbeat"
  type        = string
  sensitive   = true
}

variable "esf-cloud_id" {
  description = "Elasticsearch cloud_id for ESF"
  type        = string
  sensitive   = true
}

variable "functionbeat-es_username" {
  description = "Elasticsearch username for Functionbeat"
  type        = string
  sensitive   = true
}

variable "esf-es_username" {
  description = "Elasticsearch username for ESF"
  type        = string
  sensitive   = true
}

variable "functionbeat-es_password" {
  description = "Elasticsearch password for Functionbeat"
  type        = string
  sensitive   = true
}

variable "esf-es_password" {
  description = "Elasticsearch password for Functionbeat"
  type        = string
  sensitive   = true
}

variable "firehose-es_apikey" {
  description = "Elasticsearch APIKey for Firehose"
  type        = string
  sensitive   = true
}

# ESF variables
variable "esf-memory_size" {
  description = "Memory size for ESF"
  type        = number
  default     = 512
}

variable "esf-timeout" {
  description = "Lambda timeout for ESF"
  type        = number
  default     = 900
}

variable "esf-max_concurrency" {
  description = "Maximum concurrency for ESF"
  type        = number
  default     = 5
}


variable "esf-lambda-name" {
  description = "ESF Lambda function name"
  type        = string
}

variable "esf-version" {
  description = "ESF branch/tag to deploy"
  type        = string
}


variable "esf-config-bucket-name" {
  description = "ESF S3 config bucket name"
  type        = string
}

variable "esf-sqs-queue-name" {
  description = "ESF SQS queue name"
  type        = string
}

variable "esf-es-max-batch-bytes" {
  description = "ESF Elasticsearch Batch size"
  type        = number
  default     = 1048576000
}

variable "esf_enabled" {
  description = "Enables/Disables the SQS event trigger for ESF"
  type        = bool
  default     = true
}

# Functionbeat variables
variable "functionbeat-memory_size" {
  description = "Memory size for Functionbeat"
  type        = number
  default     = 128
}

variable "functionbeat-timeout" {
  description = "Lambda timeout for Functionbeat"
  type        = number
  default     = 3
}

variable "functionbeat-max_concurrency" {
  description = "Maximum concurrency for Functionbeat"
  type        = number
  default     = 5
}

variable "functionbeat-sqs-queue-name" {
  description = "Functionbeat SQS queue name"
  type        = string
}

variable "functionbeat_version" {
  description = "Funtionbeat version to deploy"
  type        = string
}

variable "functionbeat_lambda_name" {
  description = "Funtionbeat Lambda function name"
  type        = string
}

variable "functionbeat_enabled" {
  description = "Enables/Disables the SQS event trigger for Functionbeat"
  type        = bool
  default     = true
}

# Firehose variables
variable "firehose-delivery-stream-name" {
  description = "Firehose delivery stream name"
  type        = string
}

variable "firehose-bucket-name" {
  description = "Firehose S3 bucket name"
  type        = string
}

variable "firehose-es_url" {
  description = "Firehose ESS Url"
  type        = string
}

variable "firehose_enabled" {
  description = "Enables/Disables SNS forwarding to firehose"
  type        = bool
  default     = true
}


# Sources variables
variable "source_sns_topic" {
  description = "Source SNS topic"
  type        = string
}

# Generic variables
variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "force_destroy" {
  description = "Boolean flag to force destroy resources (e.g non-empty S3 buckets"
  type        = bool
}

# Shared Lambda config
variable "bulk_max_size" {
  description = "ESF and Functionbeat Elasticsearch Batch size"
  type        = number
  default     = 500
}


# Shared Lambda settings
variable "log_level" {
  description = "Log level for ESF and functionbeat"
  type        = string
  default     = "DEBUG"
}

variable "sqs_batch_size" {
  description = "SQS Batch Size for ESF and functionbeat"
  type        = number
  default     = 10
}

variable "sqs_batch_window" {
  description = "SQS Batch Window for ESF and functionbeat, in seconds"
  type        = number
  default     = 60
}

