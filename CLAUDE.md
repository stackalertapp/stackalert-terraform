# CLAUDE.md — StackAlert Terraform Module

## Project Overview

Terraform module that deploys **StackAlert** — a serverless AWS cost spike detection and alerting system. A Rust Lambda (arm64, `provided.al2023`) runs on EventBridge schedules to monitor AWS costs via Cost Explorer and sends alerts through 7 notification channels.

Repository: `stackalertapp/stackalert-terraform`
License: Apache 2.0

## Architecture

```
EventBridge (every 6h / daily 8am UTC)
  └─> Lambda (Rust, arm64)
        ├─> Cost Explorer API (reads cost data)
        ├─> SSM Parameter Store (read secrets via *_SSM_PARAM env vars + dedup state)
        ├─> Notification channels:
        │     Slack, Telegram, Teams, PagerDuty, SES, SNS, Webhook
        ├─> CloudWatch Logs (JSON structured)
        └─> SQS DLQ (failed invocations)
```

**Secret handling**: Secrets (webhook URLs, tokens, routing keys) are stored in SSM SecureString. Lambda receives SSM parameter **paths** via env vars (e.g. `SLACK_WEBHOOK_URL_SSM_PARAM`) and reads the actual values at runtime. Non-secret config (chat IDs, email addresses, severity levels) are passed as plain env vars.

## Quick Start

```bash
# 1. Download the Lambda artifact
./scripts/download-lambda.sh examples/telegram

# 2. Configure
cd examples/telegram
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your Telegram bot token and chat ID

# 3. Deploy
terraform init
terraform apply
```

## Lambda Artifact

The module supports two ways to provide the Lambda deployment package:

| Method | Variable | Use case |
|--------|----------|----------|
| **Local file** | `lambda_filename` | Local dev, quick start — no S3 bucket needed |
| **S3 bucket** | `artifact_s3_bucket` + `artifact_s3_key` | CI/CD, teams, production deployments |

**Helper script** (`scripts/download-lambda.sh`):
```bash
# Download latest release to current directory
./scripts/download-lambda.sh

# Download latest to a specific directory
./scripts/download-lambda.sh examples/telegram

# Download a specific version
./scripts/download-lambda.sh . v1.0.1
```

The script resolves the latest tag from the GitHub API before downloading.

## Module Layout

| File                  | Purpose                                                    |
|-----------------------|------------------------------------------------------------|
| `versions.tf`         | Terraform >= 1.10, AWS provider ~> 5.91, S3 backend (commented) |
| `variables.tf`        | 35+ inputs: region, channels, thresholds, secrets, Lambda config |
| `outputs.tf`          | Lambda ARN/name, SSM paths, DLQ, EventBridge rules, CLI invoke commands |
| `locals.tf`           | Tag merging, channel set parsing from comma-separated `notify_channels` |
| `lambda.tf`           | Lambda function (local file or S3), conditional env vars per channel, EventBridge permissions |
| `iam.tf`              | Least-privilege execution role with conditional policies (SES, SNS, STS) |
| `iam_deploy_role.tf`  | Optional GitHub Actions OIDC deployment role               |
| `ssm.tf`              | Conditional SSM SecureString params per enabled channel + optional KMS CMK |
| `eventbridge.tf`      | Spike check (rate) + daily digest (cron) rules             |
| `cloudwatch.tf`       | Log group + 3 alarms (errors, throttles, DLQ depth)       |
| `sqs.tf`              | Dead Letter Queue (14-day retention, SSE-SQS)             |
| `scripts/`            | Helper scripts (download-lambda.sh)                        |

## Examples

| Example           | Channel(s)              | Artifact   | Use case                                      |
|-------------------|-------------------------|------------|-----------------------------------------------|
| `telegram/`       | Telegram                | Local file | Quick start with Telegram bot                 |
| `single-account/` | Telegram                | S3         | Single-account setup via S3 artifact          |
| `cross-account/`  | Slack + PagerDuty       | S3         | Multi-account via STS AssumeRole + ExternalId |
| `multi-channel/`  | Slack + PagerDuty + SES | S3         | Fan-out to multiple channels, KMS enabled     |
| `webhook/`        | Webhook                 | S3         | Generic HTTP POST with bearer auth            |
| `sns/`            | SNS                     | S3         | Publish to SNS topic (email/SMS/Lambda/SQS)   |

Each example includes a `terraform.tfvars.example` file — copy to `terraform.tfvars` and fill in your values.

## Development Commands

```bash
# Format
terraform fmt -recursive

# Validate
terraform init -backend=false
terraform validate

# Lint
tflint --init
tflint

# Security scan
checkov -d . --config-file .checkov.yaml
trivy config .

# Plan & Apply
terraform plan -out=tfplan
terraform apply tfplan

# Generate docs locally (same as CI)
docker run --rm -v "$(pwd):/terraform-docs" -u "$(id -u)" \
  quay.io/terraform-docs/terraform-docs:latest \
  markdown table --output-file README.md --output-mode inject /terraform-docs
```

## CI/CD Workflows (.github/workflows/)

| Workflow        | Trigger            | What it does                                    |
|-----------------|--------------------|-------------------------------------------------|
| `validate.yml`  | PR to main         | fmt check, init, validate, tflint (comments on PR) |
| `security.yml`  | Push + PR to main  | tflint, checkov, trivy (non-blocking, uploads to Security tab) |
| `deploy.yml`    | Push to main / manual | OIDC auth, plan, apply, smoke test            |
| `docs.yml`      | PR to main         | Auto-generates README via terraform-docs        |

All third-party GitHub Actions are pinned to commit SHAs for supply chain security.

## Terraform Conventions

- **Naming**: All resources use `stackalert-${var.environment}` prefix
- **Tags**: Common tags applied via `default_tags` in the calling root module's provider + `local.common_tags`
- **No provider block in the module**: The module inherits the provider from the caller (see `examples/` for provider config with `default_tags`)
- **Channel activation**: `notify_channels` is a comma-separated string parsed into a set in `locals.tf`:
  ```hcl
  channels = toset([for c in split(",", var.notify_channels) : trimspace(c)])
  ```
- **Conditional resources**: Channel-specific SSM params, IAM policies, and env vars only created when the channel is in `notify_channels`
  ```hcl
  count = contains(local.channels, "slack") ? 1 : 0
  ```
- **Lambda env vars**: Built with `merge()` of conditional maps — each channel block adds its env vars only when enabled
- **Lambda artifact**: Uses `filename` when `lambda_filename` is set, falls back to `s3_bucket`/`s3_key` otherwise
- **IAM**: Each policy is a separate `aws_iam_role_policy` resource scoped to specific actions/resources
- **Depends-on**: Lambda explicitly depends on all IAM policy attachments (IAM eventual consistency)
- **Sensitive variables**: Marked `sensitive = true` in `variables.tf`, stored in SSM SecureString, passed to Lambda as SSM param paths (not raw values)

## Security Principles

1. **Least-privilege IAM** — every policy is resource-scoped, no wildcards on actions
2. **Secrets via SSM** — Lambda gets SSM parameter paths, reads secrets at runtime (not baked into env vars)
3. **No long-lived credentials** — GitHub Actions uses OIDC, Lambda uses execution role
4. **Encryption at rest** — SSM SecureString (AWS-managed or optional CMK), SQS SSE, optional CloudWatch KMS
5. **Confused deputy protection** — `aws:SourceAccount` condition on Lambda trust policy
6. **No VPC required** — Lambda calls only public AWS APIs; avoids unnecessary NAT Gateway cost
7. **DLQ for reliability** — failed invocations captured for debugging
8. **Static analysis** — tflint, checkov (with documented skip justifications in `.checkov.yaml`), trivy
9. **Pinned CI actions** — all third-party GitHub Actions pinned to commit SHAs

## Checkov Skip Policy

All skips are documented in `.checkov.yaml` with justifications. Before adding a new skip:
1. Verify the check cannot be satisfied by a code change
2. Document why the skip is an accepted tradeoff, not a shortcut
3. Reference the specific design decision (e.g., "no VPC because only public APIs")

## Adding a New Notification Channel

1. Add variables in `variables.tf` (mark secrets as `sensitive = true`)
2. Add conditional SSM parameter in `ssm.tf` (SecureString, respects `create_kms_key`)
3. Add SSM ARN to the `lambda_ssm` policy resources in `iam.tf`
4. Add conditional IAM policy in `iam.tf` if the channel needs AWS API access (SES, SNS)
5. Add conditional env var block in `lambda.tf` inside the `merge()` — use `*_SSM_PARAM` for secrets, plain env vars for non-secrets
6. Add the channel name to the `notify_channels` validation in `variables.tf`
7. Create or update an example in `examples/` with `terraform.tfvars.example`
8. CI will auto-generate README updates via terraform-docs

## Contribution Guidelines

### Code Standards
- Run `terraform fmt -recursive` before committing
- All variables must have `description` and `type` (enforced by tflint)
- All outputs must have `description` (enforced by tflint)
- New resources must follow the `stackalert-${var.environment}` naming convention
- IAM policies must be scoped to specific resources — no `Resource: "*"` unless the API requires it (e.g., `ce:GetCostAndUsage`)
- Secrets go in SSM SecureString; Lambda reads them via SSM param paths at runtime

### PR Process
1. Create a feature branch from `main`
2. CI runs: format check, validate, lint, security scan
3. terraform-docs auto-updates README on the PR branch
4. Merge to `main` triggers deploy workflow (plan + apply + smoke test)

### What NOT to Do
- Do not hardcode AWS credentials or account IDs
- Do not add `*.tfvars` files to the repo (gitignored, except `*.tfvars.example`)
- Do not skip checkov rules without documented justification
- Do not pass raw secrets as Lambda env vars — always use SSM param paths
- Do not use `terraform apply -auto-approve` in CI without a preceding plan artifact
- Do not add provider blocks in the module — only in calling root modules / examples
- Do not commit `lambda-arm64.zip` (gitignored)
