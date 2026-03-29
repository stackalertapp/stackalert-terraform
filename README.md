# stackalert-terraform

[![Validate](https://github.com/stackalertapp/stackalert-terraform/actions/workflows/validate.yml/badge.svg)](https://github.com/stackalertapp/stackalert-terraform/actions/workflows/validate.yml)
[![Security](https://github.com/stackalertapp/stackalert-terraform/actions/workflows/security.yml/badge.svg)](https://github.com/stackalertapp/stackalert-terraform/actions/workflows/security.yml)
[![Deploy](https://github.com/stackalertapp/stackalert-terraform/actions/workflows/deploy.yml/badge.svg)](https://github.com/stackalertapp/stackalert-terraform/actions/workflows/deploy.yml)

Terraform infrastructure for [StackAlert](https://github.com/stackalertapp/stackalert-lambda) — AWS cost spike detection with alerts via **Slack**, **Telegram**, **Microsoft Teams**, **PagerDuty**, **SES (Email)**, **SNS**, and/or **Webhook**.

## Resources Created

| Resource | Description |
|---|---|
| `aws_lambda_function` | StackAlert Rust Lambda (arm64, provided.al2023) |
| `aws_iam_role` | Least-privilege execution role |
| `aws_cloudwatch_event_rule` x 2 | Spike check (every 6h) + daily digest (08:00 UTC) |
| `aws_ssm_parameter` | Per-channel secrets (SecureString, only for enabled channels) |
| `aws_sqs_queue` | Dead-letter queue for failed invocations |
| `aws_cloudwatch_log_group` | JSON-structured Lambda logs |

## Quick Start

```bash
# 1. Download the Lambda artifact
./scripts/download-lambda.sh examples/telegram

# 2. Configure
cd examples/telegram
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Telegram bot token and chat ID

# 3. Deploy
terraform init
terraform apply
```

## Prerequisites

1. **Terraform >= 1.10** — `brew install terraform`
2. **Lambda artifact** — either:
   - **Local file** (quickest): `./scripts/download-lambda.sh` downloads the latest release from [stackalert-lambda](https://github.com/stackalertapp/stackalert-lambda/releases)
   - **S3 bucket** (for CI/CD): upload the artifact to S3 and set `artifact_s3_bucket` + `artifact_s3_key`
3. **AWS credentials** — with permissions for IAM, Lambda, SSM, SQS, EventBridge, CloudWatch, and Cost Explorer
4. **GitHub OIDC** _(for CI/CD only)_ — configure AWS OIDC provider for GitHub Actions ([guide](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services))

## GitHub Secrets & Variables

| Name | Type | Description |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Secret | IAM role ARN for GitHub Actions OIDC |
| `ARTIFACT_S3_BUCKET` | Variable | S3 bucket name for Lambda artifact |
| `AWS_REGION` | Variable | AWS region (default: `eu-central-1`) |
| `NOTIFY_CHANNELS` | Variable | Enabled channels, e.g. `telegram,slack` |
| `SLACK_WEBHOOK_URL` | Secret | Slack webhook URL _(if slack enabled)_ |
| `TELEGRAM_BOT_TOKEN` | Secret | Telegram bot token _(if telegram enabled)_ |
| `TELEGRAM_CHAT_ID` | Variable | Telegram chat/group ID _(if telegram enabled)_ |
| `TEAMS_WEBHOOK_URL` | Secret | Teams webhook URL _(if teams enabled)_ |
| `PAGERDUTY_ROUTING_KEY` | Secret | PagerDuty routing key _(if pagerduty enabled)_ |
| `WEBHOOK_URL` | Secret | Webhook URL _(if webhook enabled)_ |
| `CROSS_ACCOUNT_ROLE_ARN` | Variable | Optional: cross-account IAM role ARN |

## Lambda Artifact

The module supports two ways to provide the Lambda deployment package:

| Method | Variable | Use case |
|--------|----------|----------|
| **Local file** | `lambda_filename` | Local dev, quick start — no S3 bucket needed |
| **S3 bucket** | `artifact_s3_bucket` + `artifact_s3_key` | CI/CD, teams, production deployments |

### Helper script

```bash
# Download latest release to current directory
./scripts/download-lambda.sh

# Download to a specific directory
./scripts/download-lambda.sh examples/telegram

# Download a specific version
./scripts/download-lambda.sh . v1.0.1
```

### Usage with local file

```hcl
module "stackalert" {
  source          = "github.com/stackalertapp/stackalert-terraform"
  lambda_filename = "${path.module}/lambda-arm64.zip"
  notify_channels = "telegram"
  # ...
}
```

### Usage with S3

```hcl
module "stackalert" {
  source             = "github.com/stackalertapp/stackalert-terraform"
  artifact_s3_bucket = "my-stackalert-artifacts"
  artifact_s3_key    = "stackalert-lambda/latest.zip"
  notify_channels    = "telegram"
  # ...
}
```

## Examples

| Example | Channel(s) | Artifact | Use case |
|---------|------------|----------|----------|
| [`telegram/`](examples/telegram/) | Telegram | Local file | Quick start with Telegram bot |
| [`single-account/`](examples/single-account/) | Telegram | S3 | Single-account setup via S3 artifact |
| [`cross-account/`](examples/cross-account/) | Slack + PagerDuty | S3 | Multi-account via STS AssumeRole |
| [`multi-channel/`](examples/multi-channel/) | Slack + PagerDuty + SES | S3 | Fan-out to multiple channels, KMS |
| [`webhook/`](examples/webhook/) | Webhook | S3 | Generic HTTP POST with bearer auth |
| [`sns/`](examples/sns/) | SNS | S3 | Publish to SNS topic |

Each example includes a `terraform.tfvars.example` — copy to `terraform.tfvars` and fill in your values.

## Input Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | string | `eu-central-1` | AWS region for all resources |
| `lambda_filename` | string | `null` | Path to a local Lambda ZIP file (alternative to S3) |
| `artifact_s3_bucket` | string | `""` | S3 bucket with the Lambda ZIP (when not using `lambda_filename`) |
| `artifact_s3_key` | string | `stackalert-lambda/latest.zip` | S3 key for the ZIP |
| `environment` | string | `prod` | Deployment environment (dev/staging/prod) |
| `notify_channels` | string | `telegram` | Comma-separated channels: `slack`, `telegram`, `teams`, `pagerduty`, `ses`, `sns`, `webhook` |
| `slack_webhook_url` | string | `""` | Slack incoming webhook URL |
| `telegram_bot_token` | string | `""` | Telegram bot token |
| `telegram_chat_id` | string | `""` | Telegram chat/group ID |
| `teams_webhook_url` | string | `""` | Microsoft Teams incoming webhook URL |
| `pagerduty_routing_key` | string | `""` | PagerDuty Events API v2 routing key |
| `pagerduty_severity` | string | `error` | PagerDuty alert severity (critical/error/warning/info) |
| `ses_from_address` | string | `""` | Verified SES sender email address |
| `ses_to_addresses` | string | `""` | Comma-separated recipient email addresses |
| `sns_topic_arn` | string | `""` | SNS topic ARN to publish alerts to |
| `webhook_url` | string | `""` | Generic webhook URL for HTTP POST notifications |
| `webhook_auth_header` | string | `""` | Optional Authorization header for webhook |
| `spike_threshold_pct` | number | `50` | % above rolling average to trigger alert |
| `setup_name` | string | `StackAlert` | Human-readable name in alert messages |
| `history_days` | number | `7` | Rolling average window in days |
| `min_avg_daily_usd` | number | `0.10` | Minimum daily spend to include in spike detection |
| `dedup_cooldown_hours` | number | `6` | Hours to suppress repeat alerts |
| `max_spike_display` | number | `5` | Max services shown in spike alerts |
| `max_digest_display` | number | `10` | Max services shown in daily digest |
| `http_timeout_secs` | number | `10` | HTTP request timeout for notifications |
| `http_connect_timeout_secs` | number | `5` | HTTP connect timeout for notifications |
| `cross_account_role_arn` | string | `""` | Cross-account IAM role for Cost Explorer |
| `external_id` | string | `""` | ExternalId for STS AssumeRole |
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
  --payload '{"mode":"spike"}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json

# Trigger daily digest
aws lambda invoke \
  --function-name stackalert-prod \
  --payload '{"mode":"digest"}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json
```

## Architecture

```
EventBridge (every 6h / daily 8am UTC)
  └─> Lambda (Rust, arm64)
        ├─> Cost Explorer API (reads cost data)
        ├─> SSM Parameter Store (read secrets via SSM param paths + dedup state)
        ├─> Notification channels:
        │     Slack, Telegram, Teams, PagerDuty, SES, SNS, Webhook
        ├─> CloudWatch Logs (JSON structured)
        └─> SQS DLQ (failed invocations)
```

## Multi-Channel Configuration

StackAlert supports seven notification channels simultaneously. Enable them via `notify_channels`:

```hcl
# Telegram only (default)
notify_channels    = "telegram"
telegram_bot_token = "1234..."
telegram_chat_id   = "-1001..."

# Slack + Telegram
notify_channels    = "slack,telegram"
slack_webhook_url  = "https://hooks.slack.com/..."
telegram_bot_token = "1234..."
telegram_chat_id   = "-1001..."

# All channels
notify_channels       = "slack,telegram,teams,pagerduty,ses,sns,webhook"
slack_webhook_url     = "https://hooks.slack.com/..."
telegram_bot_token    = "1234..."
telegram_chat_id      = "-1001..."
teams_webhook_url     = "https://outlook.office.com/webhook/..."
pagerduty_routing_key = "xxxx..."
ses_from_address      = "alerts@example.com"
ses_to_addresses      = "team@example.com"
sns_topic_arn         = "arn:aws:sns:eu-central-1:123456789012:alerts"
webhook_url           = "https://example.com/hook"
```

SSM `SecureString` parameters are automatically created only for enabled channels that use secrets (Slack, Telegram, Teams, PagerDuty, Webhook). The Lambda reads secrets from SSM at runtime via `WithDecryption=true`. The IAM policy is scoped to those parameters only.

Channels that don't need secrets (SES, SNS) are configured purely via environment variables.
