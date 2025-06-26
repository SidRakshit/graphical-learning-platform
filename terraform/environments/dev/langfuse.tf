// graphical-learning-platform/terraform/environments/dev/langfuse.tf

# --- AWS Secrets Manager for Langfuse Credentials ---
resource "aws_secretsmanager_secret" "langfuse_credentials" {
  name        = "${var.project_name}-langfuse-credentials-v3-${var.environment_name}"
  description = "Credentials for the Langfuse Cloud service"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-langfuse-secret-${var.environment_name}"
  })
}

resource "aws_secretsmanager_secret_version" "langfuse_credentials_version" {
  secret_id = aws_secretsmanager_secret.langfuse_credentials.id
  secret_string = jsonencode({
    LANGFUSE_PUBLIC_KEY = var.langfuse_public_key
    LANGFUSE_SECRET_KEY = var.langfuse_secret_key
    LANGFUSE_HOST       = var.langfuse_host
  })
}
