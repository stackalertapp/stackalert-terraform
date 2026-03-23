variable "aws_region" {
  description = "AWS region for StackAlert resources (Lambda, SSM, CloudWatch logs)."
  type        = string
  default     = "eu-central-1"
}

variable "artifact_s3_bucket" {
  description = "S3 bucket containing the pre-built Lambda ZIP artifact (built by stackalert-lambda CI)."
  type        = string
}

variable "artifact_s3_key" {
  description = "S3 key for the Lambda ZIP artifact."
  type        = string
  default     = "stackalert-lambda/latest.zip"
}

variable "telegram_chat_id" {
  description = "Telegram chat/group ID to send cost alerts to."
  type        = string
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token (stored in SSM SecureString — passed here for initial creation)."
  type        = string
  sensitive   = true
}

variable "spike_threshold_pct" {
  description = "Spike threshold: alert when today's spend exceeds 7-day average by this percentage."
  type        = number
  default     = 50

  validation {
    condition     = var.spike_threshold_pct > 0 && var.spike_threshold_pct <= 1000
    error_message = "spike_threshold_pct must be between 1 and 1000."
  }
}

variable "cross_account_role_arn" {
  description = "Optional IAM role ARN in another account to assume for Cost Explorer queries. Leave empty for single-account mode."
  type        = string
  default     = ""
}

variable "spike_schedule" {
  description = "EventBridge cron/rate expression for spike checks."
  type        = string
  default     = "rate(6 hours)"
}

variable "digest_schedule" {
  description = "EventBridge cron expression for daily digest (UTC). Default: 08:00 UTC every day."
  type        = string
  default     = "cron(0 8 * * ? *)"
}

variable "lambda_memory_mb" {
  description = "Lambda memory allocation in MB."
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_mb >= 128 && var.lambda_memory_mb <= 10240
    error_message = "lambda_memory_mb must be between 128 and 10240."
  }
}

variable "lambda_timeout_seconds" {
  description = "Lambda execution timeout in seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.lambda_timeout_seconds >= 1 && var.lambda_timeout_seconds <= 900
    error_message = "lambda_timeout_seconds must be between 1 and 900."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch retention value."
  }
}

variable "environment" {
  description = "Deployment environment name (used in resource names and tags)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
