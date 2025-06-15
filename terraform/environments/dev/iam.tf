// graphical-learning-platform/terraform/environments/dev/iam.tf

# --- IAM Role for Lambda Execution (for FastAPI Backend) ---
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

# --- IAM Policy for Lambda to access AuraDB secret ---
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

# --- IAM Policy for Lambda to access Langfuse secret ---
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
