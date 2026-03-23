# stackalert-terraform

Terraform infrastructure for [StackAlert](https://github.com/stackalertapp/stackalert-lambda) — AWS cost spike detection via Telegram.

## Resources Created

| Resource | Description |
|---|---|
| `aws_lambda_function` | StackAlert Rust Lambda (arm64, provided.al2023) |
| `aws_iam_role` | Least-privilege execution role |
| `aws_cloudwatch_event_rule` × 2 | Spike check (every 6h) + daily digest (08:00 UTC) |
| `aws_ssm_parameter` | Telegram bot token (SecureString) |
| `aws_cloudwatch_log_group` | JSON-structured Lambda logs |

## Prerequisites

1. **Build the Lambda artifact** — run the [stackalert-lambda CI](https://github.com/stackalertapp/stackalert-lambda) and upload `lambda.zip` to S3
2. **S3 artifact bucket** — create an S3 bucket and set `ARTIFACT_S3_BUCKET` variable
3. **GitHub OIDC** — configure AWS OIDC provider for GitHub Actions ([guide](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services))

## GitHub Secrets & Variables

| Name | Type | Description |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Secret | IAM role ARN for GitHub Actions OIDC |
| `TELEGRAM_BOT_TOKEN` | Secret | Telegram bot token |
| `TELEGRAM_CHAT_ID` | Secret | Telegram chat/group ID |
| `ARTIFACT_S3_BUCKET` | Variable | S3 bucket name for Lambda artifact |
| `AWS_REGION` | Variable | AWS region (default: `eu-central-1`) |
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
aws_region          = "eu-central-1"
artifact_s3_bucket  = "my-stackalert-artifacts"
artifact_s3_key     = "stackalert-lambda/latest.zip"
telegram_chat_id    = "-1001234567890"
telegram_bot_token  = "1234567890:AAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
spike_threshold_pct = 50
environment         = "prod"
```

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
EventBridge (every 6h)  ──► Lambda ──► Cost Explorer API ──► Telegram
EventBridge (daily 8am) ──► Lambda ──► Cost Explorer API ──► Telegram
                                  └──► SSM (bot token)
                                  └──► CloudWatch Logs
```
