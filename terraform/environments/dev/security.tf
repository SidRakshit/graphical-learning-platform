// graphical-learning-platform/terraform/environments/dev/security.tf

// --- Security Group for SSH Access ---
resource "aws_security_group" "allow_ssh" {
  name        = "${var.project_name}-allow-ssh-${var.environment_name}"
  description = "Allow SSH inbound traffic from my IP address"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
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

// --- Security Group for Web Server Access (HTTP & HTTPS) ---
resource "aws_security_group" "allow_web" {
  name        = "${var.project_name}-allow-web-${var.environment_name}"
  description = "Allow HTTP and HTTPS inbound traffic from anywhere"
  vpc_id      = aws_vpc.main.id

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

// --- Security Group for Application Backend ---
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg-${var.environment_name}"
  description = "Security group for the application backend"
  vpc_id      = aws_vpc.main.id

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

// --- Security Group for SageMaker resources ---
resource "aws_security_group" "sagemaker_sg" {
  name        = "${var.project_name}-sagemaker-sg-${var.environment_name}"
  description = "Security group for SageMaker resources within the VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg-sagemaker-${var.environment_name}"
  })
}

// --- Security Group for the MLFlow RDS instance ---
resource "aws_security_group" "mlflow_db_sg" {
  name        = "${var.project_name}-mlflow-db-sg-${var.environment_name}"
  description = "Allow MLFlow server to connect to the RDS database"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mlflow-db-sg-${var.environment_name}"
  })
}

// --- Security Group for the MLFlow Fargate service ---
resource "aws_security_group" "mlflow_server_sg" {
  name        = "${var.project_name}-mlflow-server-sg-${var.environment_name}"
  description = "Allow inbound traffic from ALB to MLFlow server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB on port 5000"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mlflow-server-sg-${var.environment_name}"
  })
}

// --- Security Group Rule to connect MLFlow Server to its Database ---
resource "aws_security_group_rule" "db_ingress_from_mlflow_server" {
  type                     = "ingress"
  from_port                = 5432 // PostgreSQL port
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.mlflow_server_sg.id
  security_group_id        = aws_security_group.mlflow_db_sg.id
  description              = "Allow MLFlow Server to connect to RDS"
}
