// terraform/environments/dev/main.tf

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
}

data "aws_caller_identity" "current" {}

// --- Virtual Private Cloud (VPC) ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block         // From variables.tf
  enable_dns_support   = true                       // Enables DNS resolution within the VPC
  enable_dns_hostnames = true                       // Enables DNS hostnames for instances launched in the VPC

  tags = merge(local.common_tags, { // Merges common tags with a specific Name tag
    Name = "${var.project_name}-vpc-${var.environment_name}"
  })
}

// --- Subnets ---
// Public Subnet in Availability Zone 1
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id             // Associates with our main VPC
  cidr_block              = var.public_subnet_az1_cidr_block // From variables.tf
  availability_zone       = var.availability_zones[0]   // Uses the first AZ from our list variable
  map_public_ip_on_launch = true                        // Instances launched here get a public IP automatically

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet-az1-${var.environment_name}"
  })
}

// Public Subnet in Availability Zone 2
resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_az2_cidr_block
  availability_zone       = var.availability_zones[1]   // Uses the second AZ from our list variable
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet-az2-${var.environment_name}"
  })
}

// Private Subnet in Availability Zone 1
resource "aws_subnet" "private_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_az1_cidr_block
  availability_zone       = var.availability_zones[0]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-subnet-az1-${var.environment_name}"
  })
}

// Private Subnet in Availability Zone 2
resource "aws_subnet" "private_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_az2_cidr_block
  availability_zone       = var.availability_zones[1]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-subnet-az2-${var.environment_name}"
  })
}

// --- Gateways ---
// Internet Gateway for the VPC (allows communication with the internet)
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id // Attaches to our main VPC

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw-${var.environment_name}"
  })
}

// Elastic IP for NAT Gateway (a static public IP address)
resource "aws_eip" "nat_gateway_az1_eip" {
  domain   = "vpc" // Required for EIPs intended for NAT Gateways
  depends_on = [aws_internet_gateway.main_igw] // Ensures IGW is created before this EIP

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip-az1-${var.environment_name}"
  })
}

// NAT Gateway (allows instances in private subnets to access the internet)
// NAT Gateways incur hourly charges and data processing charges.
resource "aws_nat_gateway" "nat_gateway_az1" {
  allocation_id = aws_eip.nat_gateway_az1_eip.id // Associates the EIP created above
  subnet_id     = aws_subnet.public_az1.id     // NAT Gateway itself resides in a public subnet
  depends_on    = [aws_internet_gateway.main_igw] // Explicit dependency

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-gw-az1-${var.environment_name}"
  })
}

// --- Route Tables ---
// Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                // For all IPv4 traffic
    gateway_id = aws_internet_gateway.main_igw.id // Route traffic to the Internet Gateway
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt-${var.environment_name}"
  })
}

// Associate Public Subnets with the Public Route Table
resource "aws_route_table_association" "public_az1_rt_assoc" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_az2_rt_assoc" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public_rt.id
}

// Route Table for Private Subnets in AZ1 (routes outbound traffic via NAT Gateway)
resource "aws_route_table" "private_az1_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_az1.id // Route to NAT Gateway
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt-az1-${var.environment_name}"
  })
}

// Associate Private Subnet in AZ1 with its Route Table
resource "aws_route_table_association" "private_az1_rt_assoc" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private_az1_rt.id
}

// Route Table for Private Subnets in AZ2 (also routes outbound traffic via NAT Gateway in AZ1 for this basic setup)
// For higher availability, you would create a second NAT Gateway in AZ2 and a separate route table.
resource "aws_route_table" "private_az2_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_az1.id // Still using NAT GW from AZ1
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-private-rt-az2-${var.environment_name}"
  })
}

// Associate Private Subnet in AZ2 with its Route Table
resource "aws_route_table_association" "private_az2_rt_assoc" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private_az2_rt.id
}

// --- Security Groups ---

// Security Group for SSH Access
resource "aws_security_group" "allow_ssh" {
  name        = "${var.project_name}-allow-ssh-${var.environment_name}"
  description = "Allow SSH inbound traffic from my IP address"
  vpc_id      = aws_vpc.main.id // Associates this SG with your main VPC

  ingress {
    description      = "SSH from my IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.my_ip_address]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-allow-ssh-${var.environment_name}"
  })
}

// Security Group for Web Server Access (HTTP & HTTPS)
resource "aws_security_group" "allow_web" {
  name        = "${var.project_name}-allow-web-${var.environment_name}"
  description = "Allow HTTP and HTTPS inbound traffic from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-allow-web-${var.environment_name}"
  })
}

// --- AWS Secrets Manager for AuraDB Credentials ---
resource "aws_secretsmanager_secret" "auradb_credentials" {
  name        = "${var.project_name}-auradb-credentials-${var.environment_name}"
  description = "Credentials for Neo4j AuraDB instance"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-auradb-secret-${var.environment_name}"
  })
}

resource "aws_secretsmanager_secret_version" "auradb_credentials_version" {
  secret_id     = aws_secretsmanager_secret.auradb_credentials.id
  secret_string = jsonencode({ // Stores the credentials as a JSON string
    uri      = var.auradb_connection_uri
    username = var.auradb_username
    password = var.auradb_password
  })
}

// --- Security Group for Application Backend ---
// This SG will be used by your FastAPI application (e.g., if running on EC2/App Runner/Lambda in VPC)
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg-${var.environment_name}"
  description = "Security group for the application backend"
  vpc_id      = aws_vpc.main.id

  // Ingress rules will depend on what needs to talk to the app
  // For example, if an Application Load Balancer or API Gateway fronts it:
  // ingress {
  //   description = "Allow traffic from ALB/API Gateway on app port (e.g., 8000)"
  //   from_port   = 8000 // Your FastAPI app's port
  //   to_port     = 8000
  //   protocol    = "tcp"
  //   security_groups = [aws_security_group.allow_web.id] // Example: if allow_web is for an ALB
  // }
  // For now, we'll keep ingress minimal or placeholder until app deployment.

  // Egress rule to allow outbound connection to Neo4j AuraDB
  egress {
    description      = "Allow outbound to Neo4j AuraDB (Bolt port)"
    from_port        = 7687 // Neo4j Bolt port
    to_port          = 7687
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] // AuraDB is on the public internet
  }

  egress { // Default allow all other outbound traffic (can be refined)
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-app-${var.environment_name}"
  })
}

// --- IAM Role for Lambda Execution (for FastAPI Backend) ---
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role-${var.environment_name}"

  // Policy that allows Lambda to assume this role
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-lambda-exec-role-${var.environment_name}"
  })
}

// Attach AWS Managed Policy for basic Lambda logging to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// Attach AWS Managed Policy for Lambda VPC access (if you deploy Lambda in your VPC)
// This allows Lambda to create and manage Elastic Network Interfaces (ENIs) in your VPC.
resource "aws_iam_role_policy_attachment" "lambda_vpc_access_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

// --- S3 Buckets for ML ---
resource "aws_s3_bucket" "ml_datasets_bucket" {
  bucket = local.actual_ml_datasets_bucket_name // Constructed unique name

  tags = merge(local.common_tags, {
    Name = local.actual_ml_datasets_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "ml_datasets_bucket_versioning" {
  bucket = aws_s3_bucket.ml_datasets_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_datasets_bucket_sse" {
  bucket = aws_s3_bucket.ml_datasets_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ml_datasets_bucket_pab" {
  bucket                  = aws_s3_bucket.ml_datasets_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "ml_models_bucket" {
  bucket = local.actual_ml_models_bucket_name // Constructed unique name

  tags = merge(local.common_tags, {
    Name = local.actual_ml_models_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "ml_models_bucket_versioning" {
  bucket = aws_s3_bucket.ml_models_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_models_bucket_sse" {
  bucket = aws_s3_bucket.ml_models_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ml_models_bucket_pab" {
  bucket                  = aws_s3_bucket.ml_models_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


// --- VPC S3 Gateway Endpoint ---
// Allows resources in your VPC to access S3 without going over the internet
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3" // S3 service endpoint for your region
  vpc_endpoint_type = "Gateway"

  // Associate with your private and public route tables.
  // This modifies the route tables to add a route to S3 via the AWS private network.
  route_table_ids = [
    aws_route_table.public_rt.id,
    aws_route_table.private_az1_rt.id,
    aws_route_table.private_az2_rt.id
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-s3-gateway-endpoint-${var.environment_name}"
  })
}

// --- Security Group for SageMaker resources (if VPC enabled) ---
resource "aws_security_group" "sagemaker_sg" {
  name        = "${var.project_name}-sagemaker-sg-${var.environment_name}"
  description = "Security group for SageMaker endpoints, training jobs, or notebooks within the VPC"
  vpc_id      = aws_vpc.main.id

  // Example Ingress: Allow FastAPI backend (app_sg) to call a SageMaker endpoint
  // This assumes the SageMaker endpoint listens on a specific port (e.g., 8080 or 443 for HTTPS)
  // ingress {
  //   description     = "Allow App SG to call SageMaker endpoint"
  //   from_port       = 443 // Or SageMaker's specific inference port
  //   to_port         = 443
  //   protocol        = "tcp"
  //   security_groups = [aws_security_group.app_sg.id]
  // }

  // Egress: Allow SageMaker to access S3 (via VPC endpoint), ECR, and internet for packages
  // The S3 Gateway endpoint handles S3 traffic without needing a specific egress rule here for S3 IPs.
  // However, for other services like ECR or general internet (e.g. for pip install in training),
  // it might need broader egress.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-sagemaker-${var.environment_name}"
  })
}

// --- AWS Cognito User Pool ---
resource "aws_cognito_user_pool" "main_pool" {
  name = "${var.project_name}-user-pool-${var.environment_name}"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Allow users to sign themselves up
  admin_create_user_config {
    allow_admin_create_user_only = false // false means users can sign up themselves
  }

  # Standard attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true // Usually true, so users can change their email if needed
  }
  schema {
    name                = "name" // For user's full name
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  # How users can sign in (e.g., using email as username)
  username_attributes = ["email"] // Users can sign in with their email address

  # Attributes to be verified (e.g., email)
  auto_verified_attributes = ["email"]

  # MFA configuration (Off for simplicity to start)
  mfa_configuration = "OFF"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-user-pool-${var.environment_name}"
  })
}

// --- AWS Cognito User Pool Client ---
// This is what your application will use to interact with the User Pool
resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.project_name}-app-client-${var.environment_name}"
  user_pool_id = aws_cognito_user_pool.main_pool.id

  generate_secret = false // false for public clients like a web SPA (Single Page Application)

  # Allowed authentication flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",        // Secure Remote Password - preferred for client-side auth
    "ALLOW_REFRESH_TOKEN_AUTH",   // To refresh tokens
    "ALLOW_ADMIN_USER_PASSWORD_AUTH" // Can be useful for backend admin actions, or initial user creation by admin
    // "ALLOW_USER_PASSWORD_AUTH" // Generally less secure than SRP for client-side apps
  ]

  # OAuth 2.0 configuration (if you plan to use Cognito's Hosted UI or OAuth flows)
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"] // 'code' for server-side, 'implicit' for client-side (though 'code' with PKCE is now preferred for SPAs)
  allowed_oauth_scopes = [
    "phone",
    "email",
    "openid",
    "profile",
    "aws.cognito.signin.user.admin" // Standard Cognito scope
  ]

  callback_urls = var.app_callback_urls // e.g., ["http://localhost:3000/callback"]
  logout_urls   = var.app_logout_urls   // e.g., ["http://localhost:3000/login"]

  supported_identity_providers = ["COGNITO"] // Only use Cognito's own user directory for now

  prevent_user_existence_errors = "ENABLED" // Recommended to prevent attackers from guessing valid usernames

  # Default token validity periods (can be customized)
  # access_token_validity  = 60  # In minutes, default 60
  # id_token_validity      = 60  # In minutes, default 60
  # refresh_token_validity = 30  # In days, default 30
}