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

    # Confused-deputy protection: only Lambda invoked FROM this account can assume the role.
    # Without this a Lambda in another account could potentially assume it via the service principal.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "stackalert" {
  name               = "stackalert-lambda-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  description        = "Execution role for StackAlert Lambda - AWS cost spike detector"

  tags = local.common_tags
}

# ============================================================
# CloudWatch Logs: allow Lambda to write structured logs
# Scoped to the specific log group ARN — no wildcard accounts/regions
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
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/stackalert-${var.environment}:*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "cloudwatch-logs"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_logs.json
}

# ============================================================
# SSM: allow Lambda to read channel secrets
# Scoped to only the SSM parameters that were created for the
# active notification channels.
# ============================================================

data "aws_iam_policy_document" "lambda_ssm" {
  statement {
    sid    = "AllowSSMGetChannelSecrets"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    # compact() strips empty strings — only created params are included
    resources = compact([
      length(aws_ssm_parameter.slack_webhook_url) > 0 ? aws_ssm_parameter.slack_webhook_url[0].arn : "",
      length(aws_ssm_parameter.telegram_bot_token) > 0 ? aws_ssm_parameter.telegram_bot_token[0].arn : "",
      length(aws_ssm_parameter.teams_webhook_url) > 0 ? aws_ssm_parameter.teams_webhook_url[0].arn : "",
      length(aws_ssm_parameter.pagerduty_routing_key) > 0 ? aws_ssm_parameter.pagerduty_routing_key[0].arn : "",
      length(aws_ssm_parameter.webhook_url) > 0 ? aws_ssm_parameter.webhook_url[0].arn : "",
      length(aws_ssm_parameter.webhook_auth_header) > 0 ? aws_ssm_parameter.webhook_auth_header[0].arn : "",
    ])
  }

  statement {
    sid    = "AllowKMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    # Allow decrypt of the default SSM key (aws/ssm) — uses data source for consistency
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_role_policy" "lambda_ssm" {
  name   = "ssm-read-channel-secrets"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_ssm.json
}

# ============================================================
# SSM: allow Lambda to read/write dedup timestamps
# Scoped to /stackalert/{env}/dedup/* — used to prevent
# duplicate alerts within the cooldown window.
# ============================================================

data "aws_iam_policy_document" "lambda_ssm_dedup" {
  statement {
    sid    = "AllowSSMDedupReadWrite"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/stackalert/${var.environment}/dedup/*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_ssm_dedup" {
  name   = "ssm-dedup-readwrite"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_ssm_dedup.json
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
# SQS DLQ: allow Lambda to send failed invocations to the DLQ
# ============================================================

data "aws_iam_policy_document" "lambda_dlq" {
  statement {
    sid    = "AllowDLQSendMessage"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
    ]
    resources = [aws_sqs_queue.dlq.arn]
  }
}

resource "aws_iam_role_policy" "lambda_dlq" {
  name   = "sqs-dlq-send"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_dlq.json
}

# ============================================================
# X-Ray: allow Lambda to send trace data (active tracing)
# ============================================================

data "aws_iam_policy_document" "lambda_xray" {
  statement {
    sid    = "AllowXRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"] # X-Ray does not support resource-level permissions
  }
}

resource "aws_iam_role_policy" "lambda_xray" {
  name   = "xray-tracing"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_xray.json
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
# SES: allow Lambda to send emails (conditional on ses channel)
# ============================================================

data "aws_iam_policy_document" "lambda_ses" {
  count = contains(local.channels, "ses") ? 1 : 0

  statement {
    sid    = "AllowSESSendEmail"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
    ]
    resources = ["*"] # SES does not support resource-level permissions for SendEmail
  }
}

resource "aws_iam_role_policy" "lambda_ses" {
  count  = contains(local.channels, "ses") ? 1 : 0
  name   = "ses-send-email"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_ses[0].json
}

# ============================================================
# SNS: allow Lambda to publish to the configured topic
# ============================================================

data "aws_iam_policy_document" "lambda_sns" {
  count = contains(local.channels, "sns") ? 1 : 0

  statement {
    sid    = "AllowSNSPublish"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_role_policy" "lambda_sns" {
  count  = contains(local.channels, "sns") ? 1 : 0
  name   = "sns-publish"
  role   = aws_iam_role.stackalert.id
  policy = data.aws_iam_policy_document.lambda_sns[0].json
}

# ============================================================
# Data sources: current AWS account and region
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
