// graphical-learning-platform/terraform/environments/dev/security.tf

# Data source to fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# --- Security Group for SSH Access ---
resource "aws_security_group" "allow_ssh" {
  name        = "${var.project_name}-allow-ssh-${var.environment_name}"
  description = "Allow SSH inbound traffic from anywhere (default VPC)"
  vpc_id      = data.aws_vpc.default.id # Using the default VPC

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: This allows SSH from anywhere. Restrict this in a production environment.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-allow-ssh-${var.environment_name}"
  })
}

# --- Security Group for Web Server Access (HTTP & HTTPS) ---
resource "aws_security_group" "allow_web" {
  name        = "${var.project_name}-allow-web-${var.environment_name}"
  description = "Allow HTTP and HTTPS inbound traffic from anywhere (default VPC)"
  vpc_id      = data.aws_vpc.default.id # Using the default VPC

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-allow-web-${var.environment_name}"
  })
}

# --- Security Group for Application Backend ---
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg-${var.environment_name}"
  description = "Security group for the application backend (default VPC)"
  vpc_id      = data.aws_vpc.default.id # Using the default VPC

  egress {
    description = "Allow outbound to Neo4j AuraDB (Bolt port)"
    from_port   = 7687
    to_port     = 7687
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-app-${var.environment_name}"
  })
}
