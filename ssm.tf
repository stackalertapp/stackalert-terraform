# ============================================================
# SSM Parameter Store: Telegram bot token (SecureString)
# Encrypted with AWS managed key (aws/ssm)
# ============================================================

resource "aws_ssm_parameter" "telegram_bot_token" {
  name        = "/stackalert/${var.environment}/telegram-bot-token"
  description = "StackAlert Telegram bot token — managed by Terraform"
  type        = "SecureString"
  value       = var.telegram_bot_token

  # Use AWS managed SSM key (no additional KMS cost)
  key_id = "alias/aws/ssm"

  tags = {
    Name = "/stackalert/${var.environment}/telegram-bot-token"
  }

  lifecycle {
    # Prevent accidental token rotation via terraform plan diff
    ignore_changes = [value]
  }
}
