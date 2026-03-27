output "lambda_function_name" {
  description = "Name of the deployed StackAlert Lambda function."
  value       = aws_lambda_function.stackalert.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed StackAlert Lambda function."
  value       = aws_lambda_function.stackalert.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution IAM role."
  value       = aws_iam_role.stackalert.arn
}

output "ssm_parameter_paths" {
  description = "SSM parameter paths created for the enabled notification channels."
  value = compact([
    length(aws_ssm_parameter.telegram_bot_token) > 0 ? aws_ssm_parameter.telegram_bot_token[0].name : "",
    length(aws_ssm_parameter.slack_webhook_url) > 0 ? aws_ssm_parameter.slack_webhook_url[0].name : "",
    length(aws_ssm_parameter.pagerduty_routing_key) > 0 ? aws_ssm_parameter.pagerduty_routing_key[0].name : "",
  ])
}

output "deploy_role_arn" {
  description = "ARN of the GitHub Actions OIDC deployment role. Empty string when create_deploy_role = false."
  value       = length(aws_iam_role.deploy) > 0 ? aws_iam_role.deploy[0].arn : ""
}

output "log_group_name" {
  description = "CloudWatch log group name for Lambda logs."
  value       = aws_cloudwatch_log_group.stackalert.name
}

output "spike_rule_arn" {
  description = "EventBridge rule ARN for spike checks."
  value       = aws_cloudwatch_event_rule.spike_check.arn
}

output "digest_rule_arn" {
  description = "EventBridge rule ARN for daily digest."
  value       = aws_cloudwatch_event_rule.daily_digest.arn
}

output "invoke_command_spike" {
  description = "AWS CLI command to manually trigger a spike check."
  value       = "aws lambda invoke --function-name ${aws_lambda_function.stackalert.function_name} --payload '{\"mode\":\"spike\"}' --cli-binary-format raw-in-base64-out /tmp/out.json && cat /tmp/out.json"
}

output "invoke_command_digest" {
  description = "AWS CLI command to manually trigger a daily digest."
  value       = "aws lambda invoke --function-name ${aws_lambda_function.stackalert.function_name} --payload '{\"mode\":\"digest\"}' --cli-binary-format raw-in-base64-out /tmp/out.json && cat /tmp/out.json"
}

output "dlq_url" {
  description = "SQS Dead Letter Queue URL for failed Lambda invocations."
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "SQS Dead Letter Queue ARN."
  value       = aws_sqs_queue.dlq.arn
}

output "lambda_error_alarm_arn" {
  description = "ARN of the CloudWatch alarm for Lambda errors — use for SNS/PagerDuty integration."
  value       = aws_cloudwatch_metric_alarm.lambda_errors.arn
}
