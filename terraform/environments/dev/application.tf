// graphical-learning-platform/terraform/environments/dev/application.tf

# --- AWS Secrets Manager for AuraDB Credentials ---
resource "aws_secretsmanager_secret" "auradb_credentials" {
  name        = "${var.project_name}-auradb-credentials-v3-${var.environment_name}"
  description = "Credentials for Neo4j AuraDB instance"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-auradb-secret-${var.environment_name}"
  })
}

resource "aws_secretsmanager_secret_version" "auradb_credentials_version" {
  secret_id     = aws_secretsmanager_secret.auradb_credentials.id
  secret_string = jsonencode({
    uri      = var.auradb_connection_uri
    username = var.auradb_username
    password = var.auradb_password
  })
}

# --- AWS Cognito User Pool ---
resource "aws_cognito_user_pool" "main_pool" {
  name = "${var.project_name}-user-pool-${var.environment_name}"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }
  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OFF"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-user-pool-${var.environment_name}"
  })

  lifecycle {
    ignore_changes = [
    schema,
    ]
  }
}

# --- AWS Cognito User Pool Client ---
resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.project_name}-app-client-${var.environment_name}"
  user_pool_id = aws_cognito_user_pool.main_pool.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes = [
    "phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"
  ]

  callback_urls = var.app_callback_urls
  logout_urls   = var.app_logout_urls

  supported_identity_providers    = ["COGNITO"]
  prevent_user_existence_errors = "ENABLED"
}

# --- ECR Repository for Backend Docker Image ---
resource "aws_ecr_repository" "backend_api_repo" {
  name                 = local.actual_ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = local.actual_ecr_repository_name
  })
}

# --- AWS Lambda Function for FastAPI Backend ---
resource "aws_lambda_function" "fastapi_lambda" {
  function_name = "${var.project_name}-backend-api-${var.environment_name}"
  role          = aws_iam_role.lambda_execution_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.backend_api_repo.repository_url}:latest"
  timeout       = 30
  memory_size   = 512
  architectures = ["arm64"]

  # Lambda will run outside a custom VPC, accessible via API Gateway
  # No vpc_config needed

  environment {
    variables = {
      AURADB_SECRET_ARN   = aws_secretsmanager_secret.auradb_credentials.arn
      LANGFUSE_SECRET_ARN = aws_secretsmanager_secret.langfuse_credentials.arn
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-backend-api-lambda-${var.environment_name}"
  })

  depends_on = [
    aws_ecr_repository.backend_api_repo,
    aws_iam_role_policy_attachment.lambda_secrets_manager_auradb_attachment,
    aws_iam_role_policy_attachment.lambda_secrets_manager_langfuse_attachment
  ]
}

# --- API Gateway (HTTP API) ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-backend-http-api-${var.environment_name}"
  protocol_type = "HTTP"
  description   = "HTTP API for the ${var.project_name} backend"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
    allow_headers = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-http-api-${var.environment_name}"
  })
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fastapi_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-http-api-default-stage-${var.environment_name}"
  })
}

resource "aws_lambda_permission" "api_gw_lambda_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fastapi_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
