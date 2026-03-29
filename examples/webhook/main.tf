# ============================================================
# Example: Generic webhook integration
#
# Sends cost alerts to any HTTP endpoint (Datadog, Opsgenie,
# custom API, etc.) via POST with optional auth header.
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

module "stackalert" {
  source = "../../"

  aws_region         = var.aws_region
  artifact_s3_bucket = var.artifact_s3_bucket
  artifact_s3_key    = var.artifact_s3_key
  environment        = "prod"

  # Webhook with bearer auth
  notify_channels     = "webhook"
  webhook_url         = var.webhook_url
  webhook_auth_header = var.webhook_auth_header

  # Tuning
  spike_threshold_pct = 50
  setup_name          = "StackAlert Webhook"
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

variable "webhook_url" {
  type        = string
  sensitive   = true
  description = "HTTP endpoint to POST alerts to (e.g. https://api.example.com/alerts)."
}

variable "webhook_auth_header" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Optional Authorization header value (e.g. 'Bearer sk-...')."
}

# ── Outputs ────────────────────────────────────────────────────

output "lambda_function_name" {
  value = module.stackalert.lambda_function_name
}

output "invoke_spike" {
  value = module.stackalert.invoke_command_spike
}
