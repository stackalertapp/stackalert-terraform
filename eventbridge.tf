# ============================================================
# EventBridge Rules: scheduled triggers for StackAlert Lambda
# ============================================================

# Rule 1: Spike check every 6 hours
resource "aws_cloudwatch_event_rule" "spike_check" {
  name                = "stackalert-spike-check-${var.environment}"
  description         = "Triggers StackAlert spike detection every 6 hours"
  schedule_expression = var.spike_schedule

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "spike_check" {
  rule      = aws_cloudwatch_event_rule.spike_check.name
  target_id = "StackAlertSpikeCheck"
  arn       = aws_lambda_function.stackalert.arn

  # Payload: {"mode": "spike"} — matches SchedulerEvent in main.rs
  input = jsonencode({ mode = "spike" })
}

# Rule 2: Daily digest at 08:00 UTC
resource "aws_cloudwatch_event_rule" "daily_digest" {
  name                = "stackalert-daily-digest-${var.environment}"
  description         = "Triggers StackAlert daily cost digest at 08:00 UTC"
  schedule_expression = var.digest_schedule

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "daily_digest" {
  rule      = aws_cloudwatch_event_rule.daily_digest.name
  target_id = "StackAlertDailyDigest"
  arn       = aws_lambda_function.stackalert.arn

  # Payload: {"mode": "digest"} — triggers daily summary report
  input = jsonencode({ mode = "digest" })
}
