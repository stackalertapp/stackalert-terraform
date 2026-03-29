# ============================================================
# Example: Cross-account cost monitoring
#
# Deploys StackAlert in account A (monitoring account) and
# monitors costs in account B (target account) via STS AssumeRole.
#
# Step 1: Create the cross-account role in account B (see below)
# Step 2: Deploy this config in account A with the role ARN
#
# Usage:
#   cp terraform.tfvars.example terraform.tfvars
#   # Fill in artifact_s3_bucket, cross_account_role_arn, channel secrets
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

# ── Step 1: Cross-account IAM role in the TARGET account ────────────────
# Run this in account B (the monitored account), then comment it out.
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
#       Condition = {
#         StringEquals = { "sts:ExternalId" = "stackalert-cross-account" }
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

  aws_region         = var.aws_region
  artifact_s3_bucket = var.artifact_s3_bucket
  artifact_s3_key    = var.artifact_s3_key
  environment        = var.environment
  setup_name         = var.setup_name

  # Cross-account
  cross_account_role_arn = var.cross_account_role_arn
  external_id            = "stackalert-cross-account"

  # Notification — Slack + PagerDuty for ops visibility
  notify_channels       = "slack,pagerduty"
  slack_webhook_url     = var.slack_webhook_url
  pagerduty_routing_key = var.pagerduty_routing_key
  pagerduty_severity    = "warning"

  # Lower threshold for multi-account: catch smaller anomalies
  spike_threshold_pct = 30
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

variable "cross_account_role_arn" {
  type        = string
  description = "ARN of the IAM role in the target account (e.g. arn:aws:iam::TARGET_ACCOUNT_ID:role/stackalert-cost-reader)."
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

variable "pagerduty_routing_key" {
  type      = string
  sensitive = true
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "setup_name" {
  type    = string
  default = "Cross-Account Monitoring"
}

# ── Outputs ────────────────────────────────────────────────────

output "lambda_function_name" {
  value = module.stackalert.lambda_function_name
}

output "lambda_role_arn" {
  description = "Use this ARN as the Principal in the target account's trust policy."
  value       = module.stackalert.lambda_role_arn
}

output "invoke_spike" {
  value = module.stackalert.invoke_command_spike
}
