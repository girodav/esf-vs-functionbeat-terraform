# SECRETS
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

#ESF variables
variable "esf_application_id" {
  description = "ESF application id"
  type        = string
}

variable "esf_semantic_version" {
  description = "ESF semantic version"
  type        = string
}

variable "esf-stack-name" {
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

# Generic variables
variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "source_s3_bucket" {
  description = "Source S3 bucket"
  type        = string
}

