# ============================================================
# IAM Role: Lambda execution role (least-privilege)
# ============================================================

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "AllowLambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "stackalert" {
  name               = "stackalert-lambda-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  description        = "Execution role for StackAlert Lambda — AWS cost spike detector"

  tags = {
    Name = "stackalert-lambda-${var.environment}"
  }
}

# ============================================================
# CloudWatch Logs: allow Lambda to write structured logs
# ============================================================

data "aws_iam_policy_document" "lambda_logs" {
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.stackalert.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "cloudwatch-logs"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_logs.json
}

# ============================================================
# SSM: allow Lambda to read the Telegram bot token only
# ============================================================

data "aws_iam_policy_document" "lambda_ssm" {
  statement {
    sid    = "AllowSSMGetBotToken"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      aws_ssm_parameter.telegram_bot_token.arn,
    ]
  }

  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    # Allow decrypt of the default SSM key (aws/ssm)
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_role_policy" "lambda_ssm" {
  name   = "ssm-read-bot-token"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_ssm.json
}

# ============================================================
# Cost Explorer: allow Lambda to read cost data
# NOTE: Cost Explorer is a global service — no resource ARN
# ============================================================

data "aws_iam_policy_document" "lambda_cost_explorer" {
  statement {
    sid    = "AllowCostExplorerRead"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
    ]
    resources = ["*"] # Cost Explorer does not support resource-level permissions
  }
}

resource "aws_iam_role_policy" "lambda_cost_explorer" {
  name   = "cost-explorer-read"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_cost_explorer.json
}

# ============================================================
# STS: allow Lambda to assume cross-account role (optional)
# ============================================================

data "aws_iam_policy_document" "lambda_sts" {
  count = var.cross_account_role_arn != "" ? 1 : 0

  statement {
    sid    = "AllowCrossAccountAssume"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [var.cross_account_role_arn]
  }
}

resource "aws_iam_role_policy" "lambda_sts" {
  count  = var.cross_account_role_arn != "" ? 1 : 0
  name   = "sts-cross-account"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_sts[0].json
}

# ============================================================
# S3: allow Lambda to read its own artifact bucket (optional)
# for self-update patterns — skip if not needed
# ============================================================

data "aws_caller_identity" "current" {}
