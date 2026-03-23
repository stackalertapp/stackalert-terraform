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
}
