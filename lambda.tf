# ============================================================
# Lambda Function: StackAlert cost monitor
# Runtime: provided.al2023 (Rust custom runtime)
# Architecture: arm64 (Graviton2 — 20% cheaper, faster cold start)
# ============================================================

resource "aws_lambda_function" "stackalert" {
  function_name = "stackalert-${var.environment}"
  description   = "StackAlert — AWS cost spike detector. Alerts via Slack, Telegram, Teams, PagerDuty, SES, SNS, and/or Webhook."

  # Artifact: either a local file or S3
  filename  = var.lambda_filename
  s3_bucket = var.lambda_filename == null ? var.artifact_s3_bucket : null
  s3_key    = var.lambda_filename == null ? var.artifact_s3_key : null

  role    = aws_iam_role.stackalert.arn
  handler = "bootstrap" # Rust Lambda convention: binary named 'bootstrap'
  runtime = "provided.al2023"

  architectures = ["arm64"] # Graviton2: cheaper + faster for Rust

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  # Prevent runaway invocations — StackAlert only needs 1 concurrent execution at a time.
  reserved_concurrent_executions = 2

  # Active X-Ray tracing for distributed request tracing (CKV_AWS_50)
  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.stackalert.name
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = merge(
      {
        # Which channels to fan-out to (comma-separated)
        NOTIFY_CHANNELS = var.notify_channels

        # Spike detection & tuning
        SPIKE_THRESHOLD_PCT       = tostring(var.spike_threshold_pct)
        SETUP_NAME                = var.setup_name
        HISTORY_DAYS              = tostring(var.history_days)
        MIN_AVG_DAILY_USD         = tostring(var.min_avg_daily_usd)
        DEDUP_COOLDOWN_HOURS      = tostring(var.dedup_cooldown_hours)
        MAX_SPIKE_DISPLAY         = tostring(var.max_spike_display)
        MAX_DIGEST_DISPLAY        = tostring(var.max_digest_display)
        HTTP_TIMEOUT_SECS         = tostring(var.http_timeout_secs)
        HTTP_CONNECT_TIMEOUT_SECS = tostring(var.http_connect_timeout_secs)

        # Logging
        RUST_LOG = "stackalert_lambda=info,aws_sdk=warn"
        DLQ_URL  = aws_sqs_queue.dlq.url
      },

      # ── Cross-account (only set when configured) ──

      var.cross_account_role_arn != "" ? merge(
        { CROSS_ACCOUNT_ROLE_ARN = var.cross_account_role_arn },
        var.external_id != "" ? { EXTERNAL_ID = var.external_id } : {},
      ) : {},

      # ── Per-channel config (SSM param paths for secrets, env vars for non-secrets) ──

      contains(local.channels, "slack") ? {
        SLACK_WEBHOOK_URL_SSM_PARAM = aws_ssm_parameter.slack_webhook_url[0].name
      } : {},

      contains(local.channels, "telegram") ? {
        TELEGRAM_BOT_TOKEN_SSM_PARAM = aws_ssm_parameter.telegram_bot_token[0].name
        TELEGRAM_CHAT_ID             = var.telegram_chat_id
      } : {},

      contains(local.channels, "teams") ? {
        TEAMS_WEBHOOK_URL_SSM_PARAM = aws_ssm_parameter.teams_webhook_url[0].name
      } : {},

      contains(local.channels, "pagerduty") ? {
        PAGERDUTY_ROUTING_KEY_SSM_PARAM = aws_ssm_parameter.pagerduty_routing_key[0].name
        PAGERDUTY_SEVERITY              = var.pagerduty_severity
      } : {},

      contains(local.channels, "ses") ? {
        SES_FROM_ADDRESS = var.ses_from_address
        SES_TO_ADDRESSES = var.ses_to_addresses
      } : {},

      contains(local.channels, "sns") ? {
        SNS_TOPIC_ARN = var.sns_topic_arn
      } : {},

      contains(local.channels, "webhook") ? merge(
        {
          WEBHOOK_URL_SSM_PARAM = aws_ssm_parameter.webhook_url[0].name
        },
        var.webhook_auth_header != "" ? {
          WEBHOOK_AUTH_HEADER_SSM_PARAM = aws_ssm_parameter.webhook_auth_header[0].name
        } : {},
      ) : {},
    )
  }

  tags = local.common_tags

  # Explicit depends_on for IAM policies that are NOT directly referenced in this resource.
  # Ensures all permissions are attached before Lambda is created (IAM is eventually consistent).
  # Note: log group and DLQ are implicit deps via logging_config and dead_letter_config above.
  depends_on = [
    aws_iam_role_policy.lambda_logs,
    aws_iam_role_policy.lambda_ssm,
    aws_iam_role_policy.lambda_ssm_dedup,
    aws_iam_role_policy.lambda_cost_explorer,
    aws_iam_role_policy.lambda_dlq,
    aws_iam_role_policy.lambda_xray,
  ]
}

# ============================================================
# Lambda permissions: allow EventBridge to invoke the function
# ============================================================

resource "aws_lambda_permission" "eventbridge_spike" {
  statement_id  = "AllowEventBridgeSpikeCheck"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stackalert.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.spike_check.arn
}

resource "aws_lambda_permission" "eventbridge_digest" {
  statement_id  = "AllowEventBridgeDailyDigest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stackalert.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_digest.arn
}
