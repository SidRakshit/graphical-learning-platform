// graphical-learning-platform/terraform/environments/dev/variables.tf

variable "aws_region" {
  description = "The AWS region where resources will be deployed."
  type        = string
  default     = "us-east-1" # This should match the region in your backend.tf
}

variable "project_name" {
  description = "A name for the project, used to prefix resource names for uniqueness and identification."
  type        = string
  default     = "cogni-graph" # You can change this if you like
}

variable "environment_name" {
  description = "The name of the deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "auradb_connection_uri" {
  description = "The Connection URI for the Neo4j AuraDB instance."
  type        = string
  sensitive   = true # Marks this variable as sensitive
}

variable "auradb_username" {
  description = "The username for the Neo4j AuraDB instance."
  type        = string
  sensitive   = true
}

variable "auradb_password" {
  description = "The password for the Neo4j AuraDB instance."
  type        = string
  sensitive   = true
}

variable "app_callback_urls" {
  description = "A list of allowed callback URLs for your application after sign-in."
  type        = list(string)
  default     = ["http://localhost:3000/callback"] # Placeholder for local Next.js dev
}

variable "app_logout_urls" {
  description = "A list of allowed logout URLs for your application."
  type        = list(string)
  default     = ["http://localhost:3000/login"] # Placeholder for local Next.js dev
}

variable "ecr_repository_name" {
  description = "Name for the ECR repository to store the backend Docker image."
  type        = string
  default     = "" # We'll construct this in main.tf using project/environment names
}

variable "langfuse_public_key" {
  description = "The public key for the Langfuse project."
  type        = string
  sensitive   = true
}

variable "langfuse_secret_key" {
  description = "The secret key for the Langfuse project."
  type        = string
  sensitive   = true
}

variable "langfuse_host" {
  description = "The host URL for the Langfuse API (e.g., https://cloud.langfuse.com)."
  type        = string
  default     = "https://cloud.langfuse.com"
}
