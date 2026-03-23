# ============================================================
# Locals: common tags applied to all resources
# ============================================================

locals {
  common_tags = merge(
    {
      Project     = "StackAlert"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Repository  = "github.com/stackalertapp/stackalert-terraform"
    },
    var.tags
  )

  # Normalised set of active channels — used for conditional resource creation
  # and IAM policy scoping throughout the module.
  channels = toset([for c in split(",", var.notification_channels) : trimspace(c)])

  # DynamoDB region: falls back to the main aws_region when not explicitly set.
  dynamodb_region = var.dynamodb_region != "" ? var.dynamodb_region : var.aws_region
}
