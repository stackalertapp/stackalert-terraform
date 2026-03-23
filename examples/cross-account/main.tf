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
#       Principal = { AWS = "arn:aws:iam::${var.monitoring_account_id}:root" }
#       Condition = {
#         StringEquals = {
#           "sts:ExternalId" = var.external_id
#         }
#       }
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
  telegram_chat_id       = var.telegram_chat_id
  telegram_bot_token     = var.telegram_bot_token
  cross_account_role_arn = var.cross_account_role_arn
  spike_threshold_pct    = 30 # Lower threshold for multi-account monitoring
  environment            = "prod"
}

variable "aws_region" {
  default = "eu-central-1"
}

variable "monitoring_account_id" {
  description = "AWS account ID where StackAlert Lambda runs."
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
variable "cross_account_role_arn" {
  description = "ARN of the IAM role in the target account. Example: arn:aws:iam::TARGET_ACCOUNT_ID:role/stackalert-cost-reader"
}
variable "external_id" {
  description = "External ID for cross-account STS trust (security best practice)."
  default     = "stackalert"
}
