# ============================================================
# Example: Single AWS account monitoring with Telegram
#
# Minimal setup — monitors one AWS account and sends Telegram
# alerts when any service spends 50%+ more than its 7-day average.
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars
#   # Fill in artifact_s3_bucket, telegram_bot_token, telegram_chat_id
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

  default_tags {
    tags = {
      Project    = "stackalert"
      ManagedBy  = "terraform"
      Repository = "stackalertapp/stackalert-terraform"
    }
  }
}

module "stackalert" {
  source = "../../"

  aws_region         = var.aws_region
  artifact_s3_bucket = var.artifact_s3_bucket
  artifact_s3_key    = var.artifact_s3_key
  environment        = var.environment
  setup_name         = var.setup_name

  # Notification
  notify_channels    = "telegram"
  telegram_bot_token = var.telegram_bot_token
  telegram_chat_id   = var.telegram_chat_id
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

variable "telegram_bot_token" {
  type      = string
  sensitive = true
}

variable "telegram_chat_id" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "setup_name" {
  type    = string
  default = "StackAlert"
}

# ── Outputs ────────────────────────────────────────────────────

output "lambda_function_name" {
  value = module.stackalert.lambda_function_name
}

output "invoke_spike" {
  value = module.stackalert.invoke_command_spike
}

output "invoke_digest" {
  value = module.stackalert.invoke_command_digest
}
