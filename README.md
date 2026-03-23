# stackalert-terraform

Terraform infrastructure for [StackAlert](https://github.com/stackalertapp/stackalert-lambda) — AWS cost spike detection with alerts via **Slack**, **Telegram**, and/or **PagerDuty**.

## Resources Created

| Resource | Description |
|---|---|
| `aws_lambda_function` | StackAlert Rust Lambda (arm64, provided.al2023) |
| `aws_iam_role` | Least-privilege execution role |
| `aws_cloudwatch_event_rule` × 2 | Spike check (every 6h) + daily digest (08:00 UTC) |
| `aws_ssm_parameter` | Per-channel secrets (SecureString, only for enabled channels) |
| `aws_sqs_queue` | Dead-letter queue for failed invocations |
| `aws_cloudwatch_log_group` | JSON-structured Lambda logs |

## Prerequisites

1. **Build the Lambda artifact** — run the [stackalert-lambda CI](https://github.com/stackalertapp/stackalert-lambda) and upload `lambda.zip` to S3
2. **S3 artifact bucket** — create an S3 bucket and set `ARTIFACT_S3_BUCKET` variable
3. **GitHub OIDC** — configure AWS OIDC provider for GitHub Actions ([guide](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services))

## GitHub Secrets & Variables

| Name | Type | Description |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Secret | IAM role ARN for GitHub Actions OIDC |
| `ARTIFACT_S3_BUCKET` | Variable | S3 bucket name for Lambda artifact |
| `AWS_REGION` | Variable | AWS region (default: `eu-central-1`) |
| `NOTIFICATION_CHANNELS` | Variable | Enabled channels, e.g. `slack,telegram` |
| `SLACK_WEBHOOK_URL` | Secret | Slack webhook URL _(if slack enabled)_ |
| `TELEGRAM_BOT_TOKEN` | Secret | Telegram bot token _(if telegram enabled)_ |
| `TELEGRAM_CHAT_ID` | Variable | Telegram chat/group ID _(if telegram enabled)_ |
| `PAGERDUTY_ROUTING_KEY` | Secret | PagerDuty routing key _(if pagerduty enabled)_ |
| `CROSS_ACCOUNT_ROLE_ARN` | Variable | Optional: cross-account IAM role ARN |

## Usage

```bash
# Install Terraform >= 1.10
brew install terraform

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform plan
terraform apply
```

### terraform.tfvars.example

```hcl
aws_region            = "eu-central-1"
artifact_s3_bucket    = "my-stackalert-artifacts"
artifact_s3_key       = "stackalert-lambda/latest.zip"
environment           = "prod"
spike_threshold_pct   = 50

# ── Notification channels ────────────────────────────────────
# Enable one or more: slack, telegram, pagerduty
notification_channels = "slack"

# Slack (required when 'slack' is in notification_channels)
slack_webhook_url     = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXX"

# Telegram (required when 'telegram' is in notification_channels)
# telegram_bot_token  = "1234567890:AAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# telegram_chat_id    = "-1001234567890"

# PagerDuty (required when 'pagerduty' is in notification_channels)
# pagerduty_routing_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## Input Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | string | `eu-central-1` | AWS region for all resources |
| `artifact_s3_bucket` | string | — | S3 bucket with the Lambda ZIP |
| `artifact_s3_key` | string | `stackalert-lambda/latest.zip` | S3 key for the ZIP |
| `environment` | string | `prod` | Deployment environment (dev/staging/prod) |
| `notification_channels` | string | `slack` | Comma-separated channels: `slack`, `telegram`, `pagerduty` |
| `slack_webhook_url` | string | `""` | Slack incoming webhook URL |
| `telegram_bot_token` | string | `""` | Telegram bot token |
| `telegram_chat_id` | string | `""` | Telegram chat/group ID |
| `pagerduty_routing_key` | string | `""` | PagerDuty Events API v2 routing key |
| `spike_threshold_pct` | number | `50` | % above 7-day average to trigger alert |
| `cross_account_role_arn` | string | `""` | Cross-account IAM role for Cost Explorer |
| `spike_schedule` | string | `rate(6 hours)` | EventBridge schedule for spike checks |
| `digest_schedule` | string | `cron(0 8 * * ? *)` | EventBridge schedule for daily digest |
| `lambda_memory_mb` | number | `256` | Lambda memory in MB |
| `lambda_timeout_seconds` | number | `60` | Lambda timeout in seconds |
| `log_retention_days` | number | `30` | CloudWatch log retention in days |
| `create_kms_key` | bool | `false` | Create a dedicated CMK for SSM encryption |
| `tags` | map(string) | `{}` | Additional tags for all resources |

## Manual Invocation

```bash
# Trigger spike check
aws lambda invoke \
  --function-name stackalert-prod \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json
```

## Architecture

```
EventBridge (every 6h)  ──► Lambda ──► Cost Explorer API ──► Slack
EventBridge (daily 8am) ──►        └──► (per-service breakdown) ──► Telegram
                                                                └──► PagerDuty
                                  └──► SSM (channel secrets, read at deploy)
                                  └──► CloudWatch Logs + SQS DLQ
```

## Multi-Channel Configuration

StackAlert supports three notification channels simultaneously. Enable them via `notification_channels`:

```hcl
# Slack only (default)
notification_channels = "slack"
slack_webhook_url     = "https://hooks.slack.com/..."

# Slack + Telegram
notification_channels = "slack,telegram"
slack_webhook_url     = "https://hooks.slack.com/..."
telegram_bot_token    = "1234..."
telegram_chat_id      = "-1001..."

# All three channels
notification_channels = "slack,telegram,pagerduty"
slack_webhook_url     = "https://hooks.slack.com/..."
telegram_bot_token    = "1234..."
telegram_chat_id      = "-1001..."
pagerduty_routing_key = "xxxx..."
```

SSM `SecureString` parameters are automatically created only for enabled channels. The Lambda IAM policy is scoped to those parameters only.
