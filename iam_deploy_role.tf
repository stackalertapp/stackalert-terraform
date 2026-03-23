# ============================================================
# IAM Role: GitHub Actions OIDC deployment role (optional)
# ============================================================
# Enable with: create_deploy_role = true
# Required:    github_org, github_repo variables
# Prereq:      GitHub OIDC provider must already exist in the
#              account (one-time setup per account):
#              https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
#
# Permissions are tightly scoped to stackalert-* resources only.
# The role can manage Lambda, IAM (stackalert-* roles), SSM,
# SQS, CloudWatch, EventBridge, and read the S3 artifact bucket.
# ============================================================

# ── OIDC provider lookup ───────────────────────────────────

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_deploy_role ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

# ── Trust policy ───────────────────────────────────────────

data "aws_iam_policy_document" "deploy_assume_role" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid     = "AllowGitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github[0].arn]
    }

    # Audience must be sts.amazonaws.com (GitHub Actions default)
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scope to a specific repository — prevents other repos in the org from assuming this role
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  count                = var.create_deploy_role ? 1 : 0
  name                 = "stackalert-deploy-${var.environment}"
  assume_role_policy   = data.aws_iam_policy_document.deploy_assume_role[0].json
  description          = "GitHub Actions OIDC deployment role for StackAlert - ${var.environment}"
  max_session_duration = 3600 # 1 hour — sufficient for terraform plan+apply

  tags = local.common_tags
}

# ── Lambda ─────────────────────────────────────────────────

data "aws_iam_policy_document" "deploy_lambda" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid    = "ManageStackAlertLambda"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:ListVersionsByFunction",
      "lambda:PublishVersion",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:PutFunctionEventInvokeConfig",
      "lambda:GetFunctionEventInvokeConfig",
    ]
    resources = [
      "arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:stackalert-*"
    ]
  }
}

resource "aws_iam_role_policy" "deploy_lambda" {
  count  = var.create_deploy_role ? 1 : 0
  name   = "deploy-lambda"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_lambda[0].json
}

# ── IAM (stackalert-* roles + PassRole to Lambda) ─────────

data "aws_iam_policy_document" "deploy_iam" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid    = "ManageStackAlertIAMRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/stackalert-*"
    ]
  }

  statement {
    sid     = "PassRoleToLambdaOnly"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/stackalert-lambda-*"
    ]
    # PassRole is only valid when passing to the Lambda service
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "deploy_iam" {
  count  = var.create_deploy_role ? 1 : 0
  name   = "deploy-iam"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_iam[0].json
}

# ── SSM (/stackalert/* parameters only) ───────────────────

data "aws_iam_policy_document" "deploy_ssm" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid    = "ManageStackAlertSSMParams"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DeleteParameter",
      "ssm:DescribeParameters",
      "ssm:AddTagsToResource",
      "ssm:ListTagsForResource",
    ]
    resources = [
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/stackalert/*"
    ]
  }
}

resource "aws_iam_role_policy" "deploy_ssm" {
  count  = var.create_deploy_role ? 1 : 0
  name   = "deploy-ssm"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_ssm[0].json
}

# ── SQS (stackalert-* queues only) ────────────────────────

data "aws_iam_policy_document" "deploy_sqs" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid    = "ManageStackAlertSQS"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "sqs:GetQueueUrl",
      "sqs:ListQueueTags",
    ]
    resources = [
      "arn:aws:sqs:*:${data.aws_caller_identity.current.account_id}:stackalert-*"
    ]
  }
}

resource "aws_iam_role_policy" "deploy_sqs" {
  count  = var.create_deploy_role ? 1 : 0
  name   = "deploy-sqs"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_sqs[0].json
}

# ── CloudWatch Logs + Alarms ───────────────────────────────

data "aws_iam_policy_document" "deploy_cloudwatch" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid    = "ManageStackAlertLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DescribeLogGroups",
      "logs:ListTagsLogGroup",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
    ]
    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/stackalert-*",
    ]
  }

  statement {
    sid    = "ManageStackAlertAlarms"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = [
      "arn:aws:cloudwatch:*:${data.aws_caller_identity.current.account_id}:alarm:stackalert-*"
    ]
  }
}

resource "aws_iam_role_policy" "deploy_cloudwatch" {
  count  = var.create_deploy_role ? 1 : 0
  name   = "deploy-cloudwatch"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_cloudwatch[0].json
}

# ── EventBridge (stackalert-* rules only) ─────────────────

data "aws_iam_policy_document" "deploy_events" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid    = "ManageStackAlertEventRules"
    effect = "Allow"
    actions = [
      "events:PutRule",
      "events:DeleteRule",
      "events:DescribeRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:ListTargetsByRule",
      "events:TagResource",
      "events:UntagResource",
    ]
    resources = [
      "arn:aws:events:*:${data.aws_caller_identity.current.account_id}:rule/stackalert-*"
    ]
  }
}

resource "aws_iam_role_policy" "deploy_events" {
  count  = var.create_deploy_role ? 1 : 0
  name   = "deploy-events"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_events[0].json
}

# ── S3: read Lambda artifact (scoped to artifact bucket) ──

data "aws_iam_policy_document" "deploy_s3" {
  count = var.create_deploy_role ? 1 : 0

  statement {
    sid    = "ReadLambdaArtifact"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      # Exact artifact key + the whole stackalert-lambda/ prefix for flexibility
      "arn:aws:s3:::${var.artifact_s3_bucket}/${var.artifact_s3_key}",
      "arn:aws:s3:::${var.artifact_s3_bucket}/stackalert-lambda/*",
    ]
  }

  statement {
    sid    = "ListArtifactBucketPrefix"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = ["arn:aws:s3:::${var.artifact_s3_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["stackalert-lambda/*"]
    }
  }
}

resource "aws_iam_role_policy" "deploy_s3" {
  count  = var.create_deploy_role ? 1 : 0
  name   = "deploy-s3-artifact"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_s3[0].json
}

# ── KMS: only when CMK is enabled ─────────────────────────
# KMS keys have no predictable ARN before creation, so
# CreateKey must use resources = ["*"]. The alias actions are
# scoped to stackalert-* aliases.

data "aws_iam_policy_document" "deploy_kms" {
  count = var.create_deploy_role && var.create_kms_key ? 1 : 0

  statement {
    sid    = "CreateStackAlertKMSKey"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:EnableKeyRotation",
      "kms:GetKeyRotationStatus",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
    ]
    resources = ["*"] # KMS keys have no predictable ARN before creation
  }

  statement {
    sid    = "ManageStackAlertKMSAliases"
    effect = "Allow"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:ListAliases",
    ]
    resources = [
      "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:alias/stackalert-*",
      "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/*",
    ]
  }
}

resource "aws_iam_role_policy" "deploy_kms" {
  count  = var.create_deploy_role && var.create_kms_key ? 1 : 0
  name   = "deploy-kms"
  role   = aws_iam_role.deploy[0].id
  policy = data.aws_iam_policy_document.deploy_kms[0].json
}
