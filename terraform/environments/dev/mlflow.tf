// This file contains the core infrastructure for the MLFlow service.
// IAM roles are in iam.tf and Security Groups are in security.tf.

// --- RDS Database for MLFlow Backend Store ---
resource "aws_db_subnet_group" "mlflow_db_subnet_group" {
  name       = "${var.project_name}-mlflow-db-subnet-group-${var.environment_name}"
  subnet_ids = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mlflow-db-subnet-group-${var.environment_name}"
  })
}

resource "aws_db_instance" "mlflow_db" {
  identifier             = "${var.project_name}-mlflow-db-${var.environment_name}"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = var.mlflow_db_username
  password               = var.mlflow_db_password
  db_name                = "mlflowdb"
  db_subnet_group_name   = aws_db_subnet_group.mlflow_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.mlflow_db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mlflow-db-${var.environment_name}"
  })
}

// --- ECS Fargate Service for MLFlow Tracking Server ---
resource "aws_ecs_cluster" "mlflow_cluster" {
  name = "${var.project_name}-mlflow-cluster-${var.environment_name}"
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "mlflow_log_group" {
  name = "/ecs/${var.project_name}-mlflow-server-${var.environment_name}"
  tags = local.common_tags
}

resource "aws_ecs_task_definition" "mlflow_task" {
  family                   = "${var.project_name}-mlflow-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.mlflow_ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.mlflow_ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "mlflow-server"
      image     = "ghcr.io/mlflow/mlflow:v2.13.0"
      command = [
        "server",
        "--host", "0.0.0.0",
        "--port", "5000",
        "--backend-store-uri", "postgresql://${var.mlflow_db_username}:${var.mlflow_db_password}@${aws_db_instance.mlflow_db.address}:${aws_db_instance.mlflow_db.port}/${aws_db_instance.mlflow_db.db_name}",
        "--default-artifact-root", "s3://${aws_s3_bucket.ml_models_bucket.bucket}/"
      ]
      portMappings = [{ containerPort = 5000, hostPort = 5000 }]
      logConfiguration = {
        logDriver = "awslogs",
        options   = {
          "awslogs-group"         = aws_cloudwatch_log_group.mlflow_log_group.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mlflow-task-def-${var.environment_name}"
  })
}

// --- Application Load Balancer (ALB) for MLFlow UI ---
resource "aws_lb" "mlflow_alb" {
  name               = "${var.project_name}-mlflow-alb-${var.environment_name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mlflow-alb-${var.environment_name}"
  })
}

resource "aws_lb_target_group" "mlflow_tg" {
  name        = "${var.project_name}-mlflow-tg-${var.environment_name}"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check { path = "/" }
  tags = local.common_tags
}

resource "aws_lb_listener" "mlflow_http" {
  load_balancer_arn = aws_lb.mlflow_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mlflow_tg.arn
  }
}

// --- ECS Service to run the MLFlow task ---
resource "aws_ecs_service" "mlflow_service" {
  name            = "${var.project_name}-mlflow-service-${var.environment_name}"
  cluster         = aws_ecs_cluster.mlflow_cluster.id
  task_definition = aws_ecs_task_definition.mlflow_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
    security_groups  = [aws_security_group.mlflow_server_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mlflow_tg.arn
    container_name   = "mlflow-server"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.mlflow_http]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mlflow-service-${var.environment_name}"
  })
}
