// terraform/environments/dev/variables.tf

variable "aws_region" {
  description = "The AWS region where resources will be deployed."
  type        = string
  default     = "us-east-1" // This should match the region in your backend.tf
}

variable "project_name" {
  description = "A name for the project, used to prefix resource names for uniqueness and identification."
  type        = string
  default     = "cogni-graph" // You can change this if you like
}

variable "environment_name" {
  description = "The name of the deployment environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr_block" {
  description = "The main CIDR block for the Virtual Private Cloud (VPC)."
  type        = string
  default     = "10.0.0.0/16" // A common private IP address range
}

variable "public_subnet_az1_cidr_block" {
  description = "CIDR block for the public subnet in Availability Zone 1."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_az2_cidr_block" {
  description = "CIDR block for the public subnet in Availability Zone 2."
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_az1_cidr_block" {
  description = "CIDR block for the private subnet in Availability Zone 1."
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_az2_cidr_block" {
  description = "CIDR block for the private subnet in Availability Zone 2."
  type        = string
  default     = "10.0.4.0/24"
}

variable "availability_zones" {
  description = "A list of Availability Zones to use in the selected AWS region."
  type        = list(string)
  // Ensure these AZs are valid for your chosen 'aws_region' (us-east-1)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "my_ip_address" {
  description = "Your current public IP address to allow for SSH access. Find it by searching 'What is my IP' in Google."
  type        = string
  }
  
  variable "auradb_connection_uri" {
  description = "The Connection URI for the Neo4j AuraDB instance."
  type        = string
  sensitive   = true // Marks this variable as sensitive
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

variable "ml_datasets_bucket_name" {
  description = "The name for the S3 bucket to store ML datasets."
  type        = string
  default     = "" // We'll construct this in main.tf or you can set a full name here
}

variable "ml_models_bucket_name" {
  description = "The name for the S3 bucket to store ML models and artifacts."
  type        = string
  default     = "" // We'll construct this in main.tf or you can set a full name here
}

variable "app_callback_urls" {
  description = "A list of allowed callback URLs for your application after sign-in."
  type        = list(string)
  default     = ["http://localhost:3000/callback"] // Placeholder for local Next.js dev
}

variable "app_logout_urls" {
  description = "A list of allowed logout URLs for your application."
  type        = list(string)
  default     = ["http://localhost:3000/login"] // Placeholder for local Next.js dev
}

variable "ecr_repository_name" {
  description = "Name for the ECR repository to store the backend Docker image."
  type        = string
  default     = "" // We'll construct this in main.tf using project/environment names
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

variable "mlflow_db_username" {
  description = "The username for the MLFlow RDS database."
  type        = string
  default     = "mlflowadmin"
}

variable "mlflow_db_password" {
  description = "The password for the MLFlow RDS database. Must be at least 8 characters."
  type        = string
  sensitive   = true
}
