# ============================================================
# Example: Telegram notifications
#
# Sends cost spike alerts and daily digests to a Telegram chat.
#
# Prerequisites:
#   1. Create a bot via @BotFather and get the bot token
#   2. Add the bot to your group/channel
#   3. Get the chat ID (use @userinfobot or the getUpdates API)
#
# Usage:
#   ./download-lambda.sh        # download the Lambda artifact
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

  lambda_filename = "${path.module}/lambda-arm64.zip"
  environment     = var.environment

  # Telegram
  notify_channels    = "telegram"
  telegram_bot_token = var.telegram_bot_token
  telegram_chat_id   = var.telegram_chat_id

  # Tuning
  spike_threshold_pct = var.spike_threshold_pct
  setup_name          = var.setup_name
}

# ── Variables ──────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "telegram_bot_token" {
  type      = string
  sensitive = true
}

variable "telegram_chat_id" {
  type = string
}

variable "spike_threshold_pct" {
  type    = number
  default = 50
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
