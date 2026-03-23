# ============================================================
# EventBridge Rules: scheduled triggers for StackAlert
#
# Single-account mode (create_step_function = false):
#   EventBridge → Lambda directly
#
# Multi-account mode (create_step_function = true):
#   EventBridge → Step Functions state machine
#   (which then fans out to Lambda per connected account)
# ============================================================

# Rule 1: Spike check every 6 hours
resource "aws_cloudwatch_event_rule" "spike_check" {
  name                = "stackalert-spike-check-${var.environment}"
  description         = "Triggers StackAlert spike detection every 6 hours"
  schedule_expression = var.spike_schedule

  tags = local.common_tags
}

# Rule 2: Daily digest at 08:00 UTC
resource "aws_cloudwatch_event_rule" "daily_digest" {
  name                = "stackalert-daily-digest-${var.environment}"
  description         = "Triggers StackAlert daily cost digest at 08:00 UTC"
  schedule_expression = var.digest_schedule

  tags = local.common_tags
}

# ---- Single-account targets: EventBridge → Lambda ----

resource "aws_cloudwatch_event_target" "spike_check_lambda" {
  count     = var.create_step_function ? 0 : 1
  rule      = aws_cloudwatch_event_rule.spike_check.name
  target_id = "StackAlertSpikeCheck"
  arn       = aws_lambda_function.stackalert.arn

  # Payload: {"mode": "spike"} — matches SchedulerEvent in main.rs
  input = jsonencode({ mode = "spike" })
}

resource "aws_cloudwatch_event_target" "daily_digest_lambda" {
  count     = var.create_step_function ? 0 : 1
  rule      = aws_cloudwatch_event_rule.daily_digest.name
  target_id = "StackAlertDailyDigest"
  arn       = aws_lambda_function.stackalert.arn

  # Payload: {"mode": "digest"} — triggers daily summary report
  input = jsonencode({ mode = "digest" })
}

# ---- Multi-account targets: EventBridge → Step Functions ----

resource "aws_cloudwatch_event_target" "spike_check_sf" {
  count     = var.create_step_function ? 1 : 0
  rule      = aws_cloudwatch_event_rule.spike_check.name
  target_id = "StackAlertSpikeCheckSF"
  arn       = aws_sfn_state_machine.stackalert[0].arn
  role_arn  = aws_iam_role.eventbridge_sf[0].arn

  # The state machine reads `mode` from the execution input.
  input = jsonencode({ mode = "spike" })
}

resource "aws_cloudwatch_event_target" "daily_digest_sf" {
  count     = var.create_step_function ? 1 : 0
  rule      = aws_cloudwatch_event_rule.daily_digest.name
  target_id = "StackAlertDailyDigestSF"
  arn       = aws_sfn_state_machine.stackalert[0].arn
  role_arn  = aws_iam_role.eventbridge_sf[0].arn

  input = jsonencode({ mode = "digest" })
}
