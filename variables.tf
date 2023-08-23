# Secrets
variable "cloud_id" {
  description = "Elasticsearch cloud_id"
  type        = string
  sensitive   = true
}

variable "es_username" {
  description = "Elasticsearch username"
  type        = string
  sensitive   = true
}

variable "es_password" {
  description = "Elasticsearch password"
  type        = string
  sensitive   = true
}

# ESF variables
variable "esf-lambda-name" {
  description = "ESF Lambda function name"
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

variable "esf-es-max-batch-actions" {
  description = "ESF Elasticsearch Batch size"
  type        = number
  default = 500
}

variable "esf-es-max-batch-bytes" {
  description = "ESF Elasticsearch Batch size"
  type        = number
  default = 10485760
}

# Functionbeat variables
variable "functionbeat-sqs-queue-name" {
  description = "Functionbeat SQS queue name"
  type        = string
}

variable "functionbeat_version" {
  description = "Funtionbeat version to deploy"
  type        = string
}

variable "functionbeat_lambda_name" {
    description = "Funtionbeat Lambda function mae"
  type        = string
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

# Shared Lambda settings
variable "log_level" {
  description = "Log level for ESF and functionbeat"
  type        = string
  default = "DEBUG"
}

variable "memory_size" {
  description = "Memory size for ESF and functionbeat"
  type        = number
  default = 512
}

variable "timeout" {
  description = "Lambda timeout for ESF and functionbeat"
  type        = number
  default = 900
}

variable "max_concurrency" {
  description = "Maximum concurrency for ESF and functionbeat"
  type        = number
  default = 10
}

variable "sqs_batch_size" {
  description = "SQS Batch Size for ESF and functionbeat"
  type        = number
  default = 10
}

variable "sqs_batch_window" {
  description = "SQS Batch Window for ESF and functionbeat, in seconds"
  type        = number
  default = 60
}

