# esf-vs-functionbeat-terraform

This repo contains some sample Terraform module to automatically provision AWS resources to benchmark Elastic Serverless Forwarder and Functionbeat, using SQS inputs.
The resulting infrastructure is described by the following diagram (Elastic Cloud instance is not created)

```mermaid
flowchart LR
    source_s3[Source S3 bucket] --> sns[SNS topic]
    sns[SNS topic] --> sqs_1[SQS queue]
    sns[SNS topic] --> sqs_2[SQS queue]
    sqs_1[SQS queue] --> lambda_1[Elastic Serverless Forwarder]
    sqs_2[SQS queue] --> lambda_2[Functionbeat]
    lambda_1[Elastic Serverless Forwarder] --> elastic[Elastic Cloud]
    lambda_2[Functionbeat] --> elastic[Elastic Cloud]
```

## Prerequisites

Since this module executes a script ensure your machine has the following software available:

* jq
* curl
* tar

The module also expects that you have access to an [Elastic Cloud](https://www.elastic.co/cloud) deployment

## How to use

* Execute `terraform init`
* Execute `terraform apply`
