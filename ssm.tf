# ============================================================
# SSM Parameter Store: Telegram bot token (SecureString)
# Encrypted with AWS managed key (aws/ssm) by default.
# Set create_kms_key = true to use a dedicated CMK instead.
# ============================================================

resource "aws_ssm_parameter" "telegram_bot_token" {
  name        = "/stackalert/${var.environment}/telegram-bot-token"
  description = "StackAlert Telegram bot token — managed by Terraform"
  type        = "SecureString"
  value       = var.telegram_bot_token

  # Use customer-managed KMS key if created, otherwise fall back to AWS managed key
  key_id = var.create_kms_key ? aws_kms_key.ssm[0].key_id : "alias/aws/ssm"

  tags = local.common_tags

  lifecycle {
    # Prevent accidental token rotation via terraform plan diff
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
}

resource "aws_kms_alias" "ssm" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/stackalert-${var.environment}-ssm"
  target_key_id = aws_kms_key.ssm[0].key_id
}
