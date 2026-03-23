# ============================================================
# Example: Cross-account monitoring
#
# Deploys StackAlert in account A (monitoring account) and
# monitors costs in account B (target account) via STS AssumeRole.
#
# Step 1: Create the cross-account role in account B
# Step 2: Deploy StackAlert in account A with the role ARN
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

# ── Step 1: Cross-account IAM role in the TARGET account ────────────────
# Run this block with credentials for account B (the monitored account).
# Comment it out after the role is created.
#
# resource "aws_iam_role" "stackalert_reader" {
#   name = "stackalert-cost-reader"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Action    = "sts:AssumeRole"
#       Principal = { AWS = "arn:aws:iam::MONITORING_ACCOUNT_ID:root" }
#     }]
#   })
# }
#
# resource "aws_iam_role_policy" "stackalert_reader" {
#   name = "cost-explorer-read"
#   role = aws_iam_role.stackalert_reader.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = ["ce:GetCostAndUsage"]
#       Resource = ["*"]
#     }]
#   })
# }

# ── Step 2: Deploy StackAlert in the MONITORING account ─────────────────
module "stackalert" {
  source = "../../"

  aws_region             = var.aws_region
  artifact_s3_bucket     = var.artifact_s3_bucket
  artifact_s3_key        = var.artifact_s3_key
  notification_channels  = var.notification_channels
  slack_webhook_url      = var.slack_webhook_url
  telegram_chat_id       = var.telegram_chat_id
  telegram_bot_token     = var.telegram_bot_token
  cross_account_role_arn = var.cross_account_role_arn
  spike_threshold_pct    = 30 # Lower threshold for multi-account monitoring
  environment            = "prod"
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

variable "cross_account_role_arn" {
  type        = string
  description = "ARN of the IAM role in the target account. Example: arn:aws:iam::TARGET_ACCOUNT_ID:role/stackalert-cost-reader"
}
