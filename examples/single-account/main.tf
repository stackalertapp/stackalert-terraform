# ============================================================
# Example: Single AWS account monitoring
#
# Monitors one AWS account and sends Slack alerts when
# any service spends 50%+ more than its 7-day average.
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars
#   terraform init
#   terraform apply
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
}

# Deploy StackAlert using the root module
module "stackalert" {
  source = "../../"

  aws_region            = var.aws_region
  artifact_s3_bucket    = var.artifact_s3_bucket
  artifact_s3_key       = var.artifact_s3_key
  notification_channels = var.notification_channels
  slack_webhook_url     = var.slack_webhook_url
  telegram_chat_id      = var.telegram_chat_id
  telegram_bot_token    = var.telegram_bot_token
  spike_threshold_pct   = var.spike_threshold_pct
  environment           = "prod"
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "artifact_s3_bucket" {
  type = string
}

variable "artifact_s3_key" {
  type    = string
  default = "stackalert-lambda/latest.zip"
}

variable "notification_channels" {
  type    = string
  default = "slack"
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
  default   = ""
}

variable "telegram_chat_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "telegram_bot_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "spike_threshold_pct" {
  type    = number
  default = 50
}

output "lambda_function_name" {
  value = module.stackalert.lambda_function_name
}

output "invoke_command" {
  value = module.stackalert.invoke_command_spike
}
