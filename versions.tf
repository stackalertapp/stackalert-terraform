terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.91"
    }
  }

  # Uncomment and configure for remote state (recommended for teams)
  # backend "s3" {
  #   bucket         = "stackalert-terraform-state"
  #   key            = "stackalert/terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "stackalert-terraform-locks"
  #   encrypt        = true
  # }
}

# NOTE: Do not define a provider block here.
# As a reusable module, the provider is inherited from the calling root module.
# See examples/ for provider configuration.
