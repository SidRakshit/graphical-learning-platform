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
  