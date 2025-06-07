// terraform/environments/dev/outputs.tf

output "vpc_id" {
  description = "The ID of the main VPC created."
  value       = aws_vpc.main.id // References the 'id' attribute of the 'aws_vpc' resource named 'main' in main.tf
}

output "public_subnet_ids" {
  description = "A list of IDs of the public subnets created."
  value       = [
    aws_subnet.public_az1.id,
    aws_subnet.public_az2.id
  ] // Creates a list of the IDs of your public subnets
}

output "private_subnet_ids" {
  description = "A list of IDs of the private subnets created."
  value       = [
    aws_subnet.private_az1.id,
    aws_subnet.private_az2.id
  ] // Creates a list of the IDs of your private subnets
}

output "nat_gateway_public_ip" {
  description = "The public IP address of the NAT Gateway in AZ1."
  value       = aws_eip.nat_gateway_az1_eip.public_ip // References the 'public_ip' attribute of the Elastic IP
}

output "availability_zones_used" {
  description = "The Availability Zones used for the subnets."
  value       = var.availability_zones // Outputs the value of the input variable
}

output "ssh_security_group_id" {
  description = "The ID of the Security Group that allows SSH access."
  value       = aws_security_group.allow_ssh.id
}

output "web_security_group_id" {
  description = "The ID of the Security Group that allows Web (HTTP/HTTPS) access."
  value       = aws_security_group.allow_web.id
}

output "auradb_credentials_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret for AuraDB credentials."
  value       = aws_secretsmanager_secret.auradb_credentials.arn
}

output "app_security_group_id" {
  description = "The ID of the Security Group for the application backend."
  value       = aws_security_group.app_sg.id
}

output "lambda_execution_role_arn" {
  description = "The ARN of the IAM role for Lambda execution."
  value       = aws_iam_role.lambda_execution_role.arn
}

output "ml_datasets_bucket_name" {
  description = "The name of the S3 bucket for ML datasets."
  value       = aws_s3_bucket.ml_datasets_bucket.bucket
}

output "ml_models_bucket_name" {
  description = "The name of the S3 bucket for ML models and artifacts."
  value       = aws_s3_bucket.ml_models_bucket.bucket
}

output "s3_gateway_endpoint_id" {
  description = "The ID of the VPC S3 Gateway Endpoint."
  value       = aws_vpc_endpoint.s3_gateway_endpoint.id
}

output "sagemaker_security_group_id" {
  description = "The ID of the Security Group for SageMaker resources."
  value       = aws_security_group.sagemaker_sg.id
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
  value       = aws_cognito_user_pool.main_pool.endpoint // e.g., cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxxxxxx
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

output "mlflow_ui_url" {
  description = "The URL for the MLFlow Tracking Server UI."
  value       = "http://${aws_lb.mlflow_alb.dns_name}"
}

output "mlflow_tracking_uri" {
  description = "The Tracking URI to set in your ML clients (e.g., mlflow.set_tracking_uri())."
  value       = "http://${aws_lb.mlflow_alb.dns_name}"
}
