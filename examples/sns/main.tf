# ============================================================
# Example: SNS topic integration
#
# Publishes cost alerts to an SNS topic. Subscribers can be
# email, SMS, Lambda, SQS, or any SNS-supported protocol.
# Good for teams that already have an SNS-based alerting pipeline.
#
# Usage:
#   terraform init
#   terraform apply -var="artifact_s3_bucket=my-bucket" \
#                   -var="sns_topic_arn=arn:aws:sns:eu-central-1:123456789012:cost-alerts"
# ============================================================

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.91"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "stackalert"
      ManagedBy  = "terraform"
      Repository = "stackalertapp/stackalert-terraform"
    }
  }
}

# Optional: create the SNS topic in the same stack
resource "aws_sns_topic" "cost_alerts" {
  name = "stackalert-cost-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

module "stackalert" {
  source = "../../"

  aws_region         = var.aws_region
  artifact_s3_bucket = var.artifact_s3_bucket
  artifact_s3_key    = var.artifact_s3_key
  environment        = var.environment

  # SNS
  notify_channels = "sns"
  sns_topic_arn   = aws_sns_topic.cost_alerts.arn

  setup_name = var.setup_name
}

# ── Variables ──────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "artifact_s3_bucket" {
  type        = string
  description = "S3 bucket containing the pre-built Lambda ZIP artifact."
}

variable "artifact_s3_key" {
  type    = string
  default = "stackalert-lambda/latest.zip"
}

variable "alert_email" {
  type        = string
  description = "Email address to subscribe to the SNS topic."
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "setup_name" {
  type    = string
  default = "SNS Alerts"
}

# ── Outputs ────────────────────────────────────────────────────

output "lambda_function_name" {
  value = module.stackalert.lambda_function_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.cost_alerts.arn
}

output "invoke_spike" {
  value = module.stackalert.invoke_command_spike
}
