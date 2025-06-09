// graphical-learning-platform/terraform/environments/dev/iam.tf

// --- IAM Role for Lambda Execution (for FastAPI Backend) ---
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-lambda-exec-role-${var.environment_name}"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

// --- IAM Policy for Lambda to access AuraDB secret ---
resource "aws_iam_policy" "lambda_secrets_manager_auradb_policy" {
  name        = "${var.project_name}-lambda-secrets-auradb-policy-${var.environment_name}"
  description = "Allows Lambda to read the AuraDB credentials from Secrets Manager"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action   = "secretsmanager:GetSecretValue",
      Effect   = "Allow",
      Resource = aws_secretsmanager_secret.auradb_credentials.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_manager_auradb_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_secrets_manager_auradb_policy.arn
}

// --- IAM Policy for Lambda to access Langfuse secret ---
resource "aws_iam_policy" "lambda_secrets_manager_langfuse_policy" {
  name        = "${var.project_name}-lambda-secrets-langfuse-policy-${var.environment_name}"
  description = "Allows Lambda to read the Langfuse credentials from Secrets Manager"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action   = "secretsmanager:GetSecretValue",
      Effect   = "Allow",
      Resource = aws_secretsmanager_secret.langfuse_credentials.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_manager_langfuse_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_secrets_manager_langfuse_policy.arn
}

// --- IAM Role for MLFlow ECS Task ---
resource "aws_iam_role" "mlflow_ecs_task_execution_role" {
  name = "${var.project_name}-mlflow-ecs-task-exec-role-${var.environment_name}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "mlflow_ecs_task_execution_policy" {
  role       = aws_iam_role.mlflow_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// --- IAM Policy for MLFlow task to access S3 artifact bucket ---
resource "aws_iam_policy" "mlflow_s3_access_policy" {
  name        = "${var.project_name}-mlflow-s3-access-policy-${var.environment_name}"
  description = "Allows MLFlow ECS task to read/write to the models S3 bucket"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      Effect   = "Allow",
      Resource = [
        aws_s3_bucket.ml_models_bucket.arn,
        "${aws_s3_bucket.ml_models_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mlflow_s3_access_attachment" {
  role       = aws_iam_role.mlflow_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.mlflow_s3_access_policy.arn
}

// --- IAM Role for SageMaker Execution ---
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${var.project_name}-sagemaker-execution-role-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "sagemaker.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sagemaker-exec-role-${var.environment_name}"
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access_policy" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

// --- IAM Policy for Lambda to Invoke SageMaker Endpoint ---
resource "aws_iam_policy" "lambda_sagemaker_invoke_policy" {
  name        = "${var.project_name}-lambda-sagemaker-invoke-policy-${var.environment_name}"
  description = "Allows Lambda to invoke the SageMaker model endpoint"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action   = "sagemaker:InvokeEndpoint",
      Effect   = "Allow",
      // CHANGE THIS LINE
      Resource = aws_sagemaker_endpoint.gemma_2b_it_endpoint.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sagemaker_invoke_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_sagemaker_invoke_policy.arn
}