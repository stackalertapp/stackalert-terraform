# ============================================================
# CloudWatch Log Group: structured JSON logs from Lambda
# ============================================================

resource "aws_cloudwatch_log_group" "stackalert" {
  name              = "/aws/lambda/stackalert-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# ============================================================
# CloudWatch Alarms: Lambda errors, throttles, and DLQ depth
# ============================================================

# Alarm: Lambda errors > 0 in 5 min
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "stackalert-${var.environment}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "StackAlert Lambda returned errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.stackalert.function_name
  }

  tags = local.common_tags
}

# Alarm: Lambda throttles > 0 in 5 min
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "stackalert-${var.environment}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "StackAlert Lambda is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.stackalert.function_name
  }

  tags = local.common_tags
}

# Alarm: DLQ messages > 0 (Lambda failed and put message to DLQ)
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "stackalert-${var.environment}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfMessagesSent"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "StackAlert DLQ received a message — Lambda failed silently"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  tags = local.common_tags
}
