# ============================================================
# SSM Parameter Store: per-channel secrets (SecureString)
# Each parameter is only created when its channel is enabled.
# Encrypted with the AWS managed key (aws/ssm) by default.
# Set create_kms_key = true to use a dedicated CMK instead.
# ============================================================

# ── Telegram ──────────────────────────────────────────────────

resource "aws_ssm_parameter" "telegram_bot_token" {
  count = contains(local.channels, "telegram") ? 1 : 0

  name        = "/stackalert/${var.environment}/telegram-bot-token"
  description = "StackAlert Telegram bot token — managed by Terraform"
  type        = "SecureString"
  value       = var.telegram_bot_token
  key_id      = var.create_kms_key ? aws_kms_key.ssm[0].key_id : "alias/aws/ssm"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}

# ── Slack ──────────────────────────────────────────────────────

resource "aws_ssm_parameter" "slack_webhook_url" {
  count = contains(local.channels, "slack") ? 1 : 0

  name        = "/stackalert/${var.environment}/slack-webhook-url"
  description = "StackAlert Slack incoming webhook URL — managed by Terraform"
  type        = "SecureString"
  value       = var.slack_webhook_url
  key_id      = var.create_kms_key ? aws_kms_key.ssm[0].key_id : "alias/aws/ssm"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}

# ── PagerDuty ──────────────────────────────────────────────────

resource "aws_ssm_parameter" "pagerduty_routing_key" {
  count = contains(local.channels, "pagerduty") ? 1 : 0

  name        = "/stackalert/${var.environment}/pagerduty-routing-key"
  description = "StackAlert PagerDuty Events API v2 routing key — managed by Terraform"
  type        = "SecureString"
  value       = var.pagerduty_routing_key
  key_id      = var.create_kms_key ? aws_kms_key.ssm[0].key_id : "alias/aws/ssm"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}

# ============================================================
# KMS: optional customer-managed key for SSM parameter encryption
# Enable with: create_kms_key = true
# Adds key rotation and full audit trail via CloudTrail
# ============================================================

resource "aws_kms_key" "ssm" {
  count               = var.create_kms_key ? 1 : 0
  description         = "KMS key for StackAlert SSM parameters"
  enable_key_rotation = true
  tags                = local.common_tags

  # Explicit key policy (CKV2_AWS_64): account root full access + Lambda + SSM service
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.stackalert.arn
        }
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
      },
      {
        Sid    = "AllowSSMServiceUse"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "ssm" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/stackalert-${var.environment}-ssm"
  target_key_id = aws_kms_key.ssm[0].key_id
}
