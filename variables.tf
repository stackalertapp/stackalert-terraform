variable "aws_region" {
  description = "AWS region for StackAlert resources (Lambda, SSM, CloudWatch logs)."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format (e.g. eu-central-1, us-east-1)."
  }
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

variable "notification_channels" {
  description = "Comma-separated list of notification channels to enable. Valid values: slack, telegram, pagerduty. Example: \"slack,telegram\""
  type        = string
  default     = "slack"

  validation {
    condition = alltrue([
      for c in split(",", var.notification_channels) :
      contains(["slack", "telegram", "pagerduty"], trimspace(c))
    ])
    error_message = "notification_channels must be a comma-separated list containing only: slack, telegram, pagerduty."
  }
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL. Required when 'slack' is in notification_channels."
  type        = string
  sensitive   = true
  default     = ""
}

variable "telegram_bot_token" {
  description = "Telegram bot token. Required when 'telegram' is in notification_channels."
  type        = string
  sensitive   = true
  default     = ""
}

variable "telegram_chat_id" {
  description = "Telegram chat/group ID to send cost alerts to. Required when 'telegram' is in notification_channels."
  type        = string
  default     = ""
}

variable "pagerduty_routing_key" {
  description = "PagerDuty Events API v2 routing/integration key. Required when 'pagerduty' is in notification_channels."
  type        = string
  sensitive   = true
  default     = ""
}

variable "spike_threshold_pct" {
  description = "Spike threshold: alert when today's spend exceeds 7-day average by this percentage."
  type        = number
  default     = 50

  validation {
    condition     = var.spike_threshold_pct >= 1 && var.spike_threshold_pct <= 500
    error_message = "spike_threshold_pct must be between 1 and 500."
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

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "create_kms_key" {
  description = "When true, creates a dedicated customer-managed KMS key for SSM parameter encryption. When false (default), uses the AWS managed key (alias/aws/ssm)."
  type        = bool
  default     = false
}

variable "create_deploy_role" {
  description = "When true, creates a least-privilege GitHub Actions OIDC deployment role scoped to stackalert-* resources. Requires the GitHub OIDC provider to already exist in the account and github_org + github_repo to be set."
  type        = bool
  default     = false
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repository. Required when create_deploy_role = true."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix). Required when create_deploy_role = true."
  type        = string
  default     = ""
}

variable "create_step_function" {
  description = "When true, creates an AWS Step Functions state machine for multi-account fan-out. EventBridge targets the state machine instead of Lambda directly. Requires a DynamoDB table with connected account records."
  type        = bool
  default     = false
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name containing connected account records (written by the StackAlert dashboard). Required when create_step_function = true."
  type        = string
  default     = "stackalert"
}

variable "dynamodb_region" {
  description = "AWS region of the DynamoDB accounts table. Defaults to var.aws_region when left empty."
  type        = string
  default     = ""
}

variable "step_function_max_concurrency" {
  description = "Maximum number of customer accounts checked concurrently by the Step Functions Map state. Tune based on Lambda concurrency quota."
  type        = number
  default     = 10

  validation {
    condition     = var.step_function_max_concurrency >= 1 && var.step_function_max_concurrency <= 40
    error_message = "step_function_max_concurrency must be between 1 and 40."
  }
}
