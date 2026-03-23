# ============================================================
# CloudWatch Log Group: structured JSON logs from Lambda
# ============================================================

resource "aws_cloudwatch_log_group" "stackalert" {
  name              = "/aws/lambda/stackalert-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "stackalert-${var.environment}"
  }
}
