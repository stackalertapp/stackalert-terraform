# ============================================================
# Lambda Function: StackAlert cost monitor
# Runtime: provided.al2023 (Rust custom runtime)
# Architecture: arm64 (Graviton2 — 20% cheaper, faster cold start)
# ============================================================

resource "aws_lambda_function" "stackalert" {
  function_name = "stackalert-${var.environment}"
  description   = "StackAlert — AWS cost spike detector. Alerts via Telegram when spend exceeds threshold."

  # Artifact from stackalert-lambda CI (built in GitHub Actions, uploaded to S3)
  s3_bucket = var.artifact_s3_bucket
  s3_key    = var.artifact_s3_key

  role    = aws_iam_role.stackalert.arn
  handler = "bootstrap" # Rust Lambda convention: binary named 'bootstrap'
  runtime = "provided.al2023"

  architectures = ["arm64"] # Graviton2: cheaper + faster for Rust

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds

  # Prevent runaway invocations — StackAlert only needs 1 concurrent execution at a time
  reserved_concurrent_executions = 2

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.stackalert.name
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN_SSM_PARAM = aws_ssm_parameter.telegram_bot_token.name
      TELEGRAM_CHAT_ID             = var.telegram_chat_id
      SPIKE_THRESHOLD_PCT          = tostring(var.spike_threshold_pct)
      CROSS_ACCOUNT_ROLE_ARN       = var.cross_account_role_arn
      RUST_LOG                     = "stackalert_lambda=info,aws_sdk=warn"
      DLQ_URL                      = aws_sqs_queue.dlq.url
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy.lambda_logs,
    aws_iam_role_policy.lambda_ssm,
    aws_iam_role_policy.lambda_cost_explorer,
    aws_iam_role_policy.lambda_dlq,
    aws_cloudwatch_log_group.stackalert,
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
