# ============================================================
# Example: Multi-channel notifications
#
# Sends alerts to multiple channels simultaneously:
# - Slack for team visibility
# - PagerDuty for on-call escalation (critical spikes only)
# - SES email for management reporting
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

  artifact_s3_bucket = var.artifact_s3_bucket
  artifact_s3_key    = var.artifact_s3_key
  environment        = var.environment

  # Fan out to Slack + PagerDuty + SES
  notify_channels = "slack,pagerduty,ses"

  # Slack
  slack_webhook_url = var.slack_webhook_url

  # PagerDuty — route to the cost-alerts service
  pagerduty_routing_key = var.pagerduty_routing_key
  pagerduty_severity    = "critical"

  # SES — weekly digest to finance team
  ses_from_address = var.ses_from_address
  ses_to_addresses = var.ses_to_addresses

  # Tuning
  spike_threshold_pct = 40
  setup_name          = var.setup_name
  history_days        = 14
  min_avg_daily_usd   = 1.00

  # Optional: customer-managed KMS key for SSM secrets
  create_kms_key = true
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

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

variable "pagerduty_routing_key" {
  type      = string
  sensitive = true
}

variable "ses_from_address" {
  type        = string
  description = "Verified SES sender address (e.g. alerts@example.com)."
}

variable "ses_to_addresses" {
  type        = string
  description = "Comma-separated recipient list (e.g. finance@example.com,ops@example.com)."
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "setup_name" {
  type    = string
  default = "Production"
}

# ── Outputs ────────────────────────────────────────────────────

output "lambda_function_name" {
  value = module.stackalert.lambda_function_name
}

output "ssm_parameter_paths" {
  value = module.stackalert.ssm_parameter_paths
}

output "invoke_spike" {
  value = module.stackalert.invoke_command_spike
}

output "invoke_digest" {
  value = module.stackalert.invoke_command_digest
}
