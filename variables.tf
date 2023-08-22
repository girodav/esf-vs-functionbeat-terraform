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
variable "esf_application_id" {
  description = "ESF application id"
  type        = string
}

variable "esf_semantic_version" {
  description = "ESF semantic version"
  type        = string
}

variable "esf-lambda-name" {
  description = "ESF cloudformation stack name"
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
variable "source_s3_bucket" {
  description = "Source S3 bucket"
  type        = string
}

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
  default = 5500
}

variable "timeout" {
  description = "Lambda timeout for ESF and functionbeat"
  type        = number
  default = 900
}

variable "max_concurrency" {
  description = "Maximum concurrency for ESF and functionbeat"
  type        = number
  default = 120
}

variable "sqs_batch_size" {
  description = "SQS Batch Size for ESF and functionbeat"
  type        = number
  default = 500
}

variable "sqs_batch_window" {
  description = "SQS Batch Window for ESF and functionbeat, in seconds"
  type        = number
  default = 60
}

