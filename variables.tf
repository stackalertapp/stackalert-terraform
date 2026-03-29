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

# ============================================================
# Notification channels
# ============================================================

variable "notify_channels" {
  description = "Comma-separated list of notification channels to enable. Valid values: slack, telegram, teams, pagerduty, ses, sns, webhook. Example: \"slack,telegram\""
  type        = string
  default     = "telegram"

  validation {
    condition = alltrue([
      for c in split(",", var.notify_channels) :
      contains(["slack", "telegram", "teams", "pagerduty", "ses", "sns", "webhook"], trimspace(c))
    ])
    error_message = "notify_channels must be a comma-separated list containing only: slack, telegram, teams, pagerduty, ses, sns, webhook."
  }
}

# ── Slack ──────────────────────────────────────────────────────

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL. Required when 'slack' is in notify_channels."
  type        = string
  sensitive   = true
  default     = ""
}

# ── Telegram ───────────────────────────────────────────────────

variable "telegram_bot_token" {
  description = "Telegram bot token. Required when 'telegram' is in notify_channels."
  type        = string
  sensitive   = true
  default     = ""
}

variable "telegram_chat_id" {
  description = "Telegram chat/group ID to send cost alerts to. Required when 'telegram' is in notify_channels."
  type        = string
  default     = ""
}

# ── Microsoft Teams ────────────────────────────────────────────

variable "teams_webhook_url" {
  description = "Microsoft Teams incoming webhook URL. Required when 'teams' is in notify_channels."
  type        = string
  sensitive   = true
  default     = ""
}

# ── PagerDuty ──────────────────────────────────────────────────

variable "pagerduty_routing_key" {
  description = "PagerDuty Events API v2 routing/integration key. Required when 'pagerduty' is in notify_channels."
  type        = string
  sensitive   = true
  default     = ""
}

variable "pagerduty_severity" {
  description = "PagerDuty alert severity. Only used when 'pagerduty' is in notify_channels."
  type        = string
  default     = "error"

  validation {
    condition     = contains(["critical", "error", "warning", "info"], var.pagerduty_severity)
    error_message = "pagerduty_severity must be one of: critical, error, warning, info."
  }
}

# ── SES (Email) ────────────────────────────────────────────────

variable "ses_from_address" {
  description = "Verified SES sender email address. Required when 'ses' is in notify_channels."
  type        = string
  default     = ""
}

variable "ses_to_addresses" {
  description = "Comma-separated list of recipient email addresses. Required when 'ses' is in notify_channels."
  type        = string
  default     = ""
}

# ── SNS ────────────────────────────────────────────────────────

variable "sns_topic_arn" {
  description = "SNS topic ARN to publish alerts to. Required when 'sns' is in notify_channels."
  type        = string
  default     = ""
}

# ── Webhook ────────────────────────────────────────────────────

variable "webhook_url" {
  description = "Webhook URL for generic HTTP POST notifications. Required when 'webhook' is in notify_channels."
  type        = string
  sensitive   = true
  default     = ""
}

variable "webhook_auth_header" {
  description = "Optional Authorization header value for webhook requests (e.g. 'Bearer token'). Only used when 'webhook' is in notify_channels."
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================
# Spike detection & tuning
# ============================================================

variable "spike_threshold_pct" {
  description = "Spike threshold: alert when today's spend exceeds rolling average by this percentage."
  type        = number
  default     = 50

  validation {
    condition     = var.spike_threshold_pct >= 1 && var.spike_threshold_pct <= 500
    error_message = "spike_threshold_pct must be between 1 and 500."
  }
}

variable "setup_name" {
  description = "Human-readable name shown in alert messages (e.g. 'Production', 'Staging')."
  type        = string
  default     = "StackAlert"
}

variable "history_days" {
  description = "Number of days for the rolling average window used in spike detection."
  type        = number
  default     = 7

  validation {
    condition     = var.history_days >= 1 && var.history_days <= 90
    error_message = "history_days must be between 1 and 90."
  }
}

variable "min_avg_daily_usd" {
  description = "Minimum average daily spend (USD) for a service to be included in spike detection. Filters noise from low-spend services."
  type        = number
  default     = 0.10
}

variable "dedup_cooldown_hours" {
  description = "Hours to suppress repeat alerts for the same service spike."
  type        = number
  default     = 6

  validation {
    condition     = var.dedup_cooldown_hours >= 0 && var.dedup_cooldown_hours <= 168
    error_message = "dedup_cooldown_hours must be between 0 and 168 (1 week)."
  }
}

variable "max_spike_display" {
  description = "Maximum number of services to display in a spike alert."
  type        = number
  default     = 5
}

variable "max_digest_display" {
  description = "Maximum number of services to display in a daily digest."
  type        = number
  default     = 10
}

variable "http_timeout_secs" {
  description = "HTTP request timeout in seconds for notification delivery."
  type        = number
  default     = 10
}

variable "http_connect_timeout_secs" {
  description = "HTTP connect timeout in seconds for notification delivery."
  type        = number
  default     = 5
}

# ============================================================
# Cross-account monitoring
# ============================================================

variable "cross_account_role_arn" {
  description = "Optional IAM role ARN in another account to assume for Cost Explorer queries. Leave empty for single-account mode."
  type        = string
  default     = ""
}

variable "external_id" {
  description = "Optional ExternalId for STS AssumeRole when using cross-account monitoring."
  type        = string
  default     = ""
}

# ============================================================
# Scheduling
# ============================================================

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

# ============================================================
# Lambda configuration
# ============================================================

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