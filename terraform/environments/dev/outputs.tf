// graphical-learning-platform/terraform/environments/dev/outputs.tf

output "auradb_credentials_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret for AuraDB credentials."
  value       = aws_secretsmanager_secret.auradb_credentials.arn
}

output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool."
  value       = aws_cognito_user_pool.main_pool.id
}

output "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client."
  value       = aws_cognito_user_pool_client.app_client.id
}

output "cognito_user_pool_endpoint" {
  description = "The endpoint for the Cognito User Pool (useful for federation, metadata)."
  value       = aws_cognito_user_pool.main_pool.endpoint # e.g., cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxxxxxx
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository for the backend API."
  value       = aws_ecr_repository.backend_api_repo.repository_url
}

output "lambda_function_name" {
  description = "The name of the FastAPI Lambda function."
  value       = aws_lambda_function.fastapi_lambda.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the FastAPI Lambda function."
  value       = aws_lambda_function.fastapi_lambda.arn
}

output "api_gateway_endpoint_url" {
  description = "The invocation URL for the HTTP API Gateway default stage."
  value       = aws_apigatewayv2_stage.default_stage.invoke_url
}

output "langfuse_credentials_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret for Langfuse credentials."
  value       = aws_secretsmanager_secret.langfuse_credentials.arn
}
