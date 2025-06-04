// terraform/environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "cogni-graph-terraform-state-dev"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cogni-graph-terraform-state-dev"
    encrypt        = true
  }
}