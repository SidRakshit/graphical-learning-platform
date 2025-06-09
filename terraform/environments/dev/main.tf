// graphical-learning-platform/terraform/environments/dev/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" // Using a recent version of the AWS provider
    }
  }
  required_version = ">= 1.0" // Specifies the minimum Terraform version
}

provider "aws" {
  region = var.aws_region // Uses the 'aws_region' variable from variables.tf
}

data "aws_caller_identity" "current" {}

// Locals block for defining common values, like tags
locals {
  s3_bucket_prefix = "${var.project_name}-${var.environment_name}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment_name // Assuming you named it environment_name in variables.tf
    ManagedBy   = "Terraform"  
  }
  actual_ml_datasets_bucket_name = "${local.s3_bucket_prefix}-ml-datasets-${data.aws_caller_identity.current.account_id}"
  actual_ml_models_bucket_name   = "${local.s3_bucket_prefix}-ml-models-${data.aws_caller_identity.current.account_id}"
  actual_ecr_repository_name = "${var.project_name}-${var.environment_name}-backend-api"
}
