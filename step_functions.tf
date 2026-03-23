# ============================================================
# Step Functions: multi-account fan-out state machine
#
# Only created when var.create_step_function = true.
#
# Architecture:
#   EventBridge → Step Functions → ListAccounts (Lambda)
#                               → Map(CheckAccount per account)
#
# Each connected account is checked independently — a failure
# in one account does NOT block the others (Catch → Pass).
# ============================================================

# ---- IAM: Step Functions execution role (invokes Lambda) ----

data "aws_iam_policy_document" "sf_assume_role" {
  count = var.create_step_function ? 1 : 0

  statement {
    sid     = "AllowStepFunctionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    # Confused-deputy protection: only SF in this account can assume this role.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "stepfunctions" {
  count              = var.create_step_function ? 1 : 0
  name               = "stackalert-sf-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.sf_assume_role[0].json
  description        = "Execution role for the StackAlert Step Functions state machine"
  tags               = local.common_tags
}

data "aws_iam_policy_document" "sf_invoke_lambda" {
  count = var.create_step_function ? 1 : 0

  statement {
    sid     = "AllowInvokeStackAlertLambda"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    # Include both the unqualified ARN and any version/alias qualifiers.
    resources = [
      aws_lambda_function.stackalert.arn,
      "${aws_lambda_function.stackalert.arn}:*",
    ]
  }

  statement {
    sid    = "AllowXRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]
    resources = ["*"] # X-Ray does not support resource-level permissions
  }
}

resource "aws_iam_role_policy" "sf_invoke_lambda" {
  count  = var.create_step_function ? 1 : 0
  name   = "invoke-stackalert-lambda"
  role   = aws_iam_role.stepfunctions[0].id
  policy = data.aws_iam_policy_document.sf_invoke_lambda[0].json
}

# ---- State Machine ----

resource "aws_sfn_state_machine" "stackalert" {
  count    = var.create_step_function ? 1 : 0
  name     = "stackalert-${var.environment}"
  role_arn = aws_iam_role.stepfunctions[0].arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/templates/state_machine.json.tpl", {
    lambda_arn      = aws_lambda_function.stackalert.arn
    max_concurrency = var.step_function_max_concurrency
  })

  logging_configuration {
    # ERROR-level only — execution history is visible in the console regardless.
    # Upgrade to ALL for debugging.
    level                  = "ERROR"
    include_execution_data = false
  }

  tracing_configuration {
    enabled = true
  }

  tags = local.common_tags
}

# ---- IAM: EventBridge → Step Functions ----
# EventBridge rules targeting a state machine require a role with
# states:StartExecution — they cannot use a resource-based policy alone.

data "aws_iam_policy_document" "eb_sf_assume" {
  count = var.create_step_function ? 1 : 0

  statement {
    sid     = "AllowEventBridgeAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "eventbridge_sf" {
  count              = var.create_step_function ? 1 : 0
  name               = "stackalert-eb-sf-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.eb_sf_assume[0].json
  description        = "Allows EventBridge to start StackAlert Step Functions executions"
  tags               = local.common_tags
}

data "aws_iam_policy_document" "eb_sf_start" {
  count = var.create_step_function ? 1 : 0

  statement {
    sid     = "AllowStartExecution"
    effect  = "Allow"
    actions = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.stackalert[0].arn]
  }
}

resource "aws_iam_role_policy" "eb_sf_start" {
  count  = var.create_step_function ? 1 : 0
  name   = "start-stackalert-execution"
  role   = aws_iam_role.eventbridge_sf[0].id
  policy = data.aws_iam_policy_document.eb_sf_start[0].json
}

# ---- Lambda permission: allow Step Functions to invoke Lambda ----

resource "aws_lambda_permission" "stepfunctions" {
  count         = var.create_step_function ? 1 : 0
  statement_id  = "AllowStepFunctionsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stackalert.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.stackalert[0].arn
}
