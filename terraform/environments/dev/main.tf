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
  common_tags = {
    Project     = var.project_name
    Environment = var.environment_name // Assuming you named it environment_name in variables.tf
    ManagedBy   = "Terraform"
  }
}

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