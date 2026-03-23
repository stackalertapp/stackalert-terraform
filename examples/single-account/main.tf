# ============================================================
# Example: Single AWS account monitoring
#
# Monitors one AWS account and sends Telegram alerts when
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

  aws_region          = var.aws_region
  artifact_s3_bucket  = var.artifact_s3_bucket
  artifact_s3_key     = var.artifact_s3_key
  telegram_chat_id    = var.telegram_chat_id
  telegram_bot_token  = var.telegram_bot_token
  spike_threshold_pct = var.spike_threshold_pct
  environment         = "prod"
}

variable "aws_region" {
  default = "eu-central-1"
}

variable "artifact_s3_bucket" {}
variable "artifact_s3_key" {
  default = "stackalert-lambda/latest.zip"
}
variable "telegram_chat_id" {
  sensitive = true
}
variable "telegram_bot_token" {
  sensitive = true
}
variable "spike_threshold_pct" {
  default = 50
}

output "lambda_function_name" {
  value = module.stackalert.lambda_function_name
}

output "invoke_command" {
  value = module.stackalert.invoke_command_spike
}
