# ============================================================
# SQS Dead Letter Queue: captures failed Lambda invocations
# Retains messages for 14 days for debugging and alerting
# ============================================================

resource "aws_sqs_queue" "dlq" {
  name                      = "stackalert-${var.environment}-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = data.aws_iam_policy_document.dlq.json
}

data "aws_iam_policy_document" "dlq" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_lambda_function.stackalert.arn]
    }
  }
}
