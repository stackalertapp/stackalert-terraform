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

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "stackalert"
      ManagedBy   = "terraform"
      Repository  = "stackalertapp/stackalert-terraform"
    }
  }
}

# Cost Explorer MUST be queried from us-east-1 (AWS requirement)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "stackalert"
      ManagedBy   = "terraform"
      Repository  = "stackalertapp/stackalert-terraform"
    }
  }
}
