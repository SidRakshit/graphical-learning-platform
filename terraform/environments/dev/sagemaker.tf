// graphical-learning-platform/terraform/environments/dev/terraform.tf

resource "aws_sagemaker_model" "gemma_2b_it_model" {
  name               = "${var.project_name}-gemma-2b-it-model-${var.environment_name}"
  execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    # This is the standard TGI container for Hugging Face models
    image = "${var.jumpstart_account_ids[var.aws_region]}.dkr.ecr.${var.aws_region}.amazonaws.com/huggingface-pytorch-tgi-inference:2.1.1-tgi1.4.2-gpu-py310-cu121-ubuntu22.04"

    # We pass the model ID directly to the container as an environment variable.
    # The container handles downloading the model from Hugging Face.
    environment = {
      "HF_MODEL_ID" = "google/gemma-2b-it"
      "HUGGING_FACE_HUB_TOKEN" = var.huggingface_hub_token    
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-gemma-2b-it-model-${var.environment_name}"
  })
}

resource "aws_sagemaker_endpoint_configuration" "gemma_2b_it_endpoint_config" {
  name = "${var.project_name}-gemma-2b-it-endpoint-config-${var.environment_name}"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.gemma_2b_it_model.name
    initial_instance_count = 1
    instance_type          = "ml.g5.2xlarge"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-gemma-2b-it-config-${var.environment_name}"
  })
}

resource "aws_sagemaker_endpoint" "gemma_2b_it_endpoint" {
  name                 = "${var.project_name}-gemma-2b-it-endpoint-${var.environment_name}"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.gemma_2b_it_endpoint_config.name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-gemma-2b-it-endpoint-${var.environment_name}"
  })
}

resource "aws_secretsmanager_secret" "huggingface_token" {
  name        = "${var.project_name}-huggingface-token-${var.environment_name}"
  description = "Hugging Face Hub token for SageMaker model downloads"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-huggingface-secret-${var.environment_name}"
  })
}

resource "aws_secretsmanager_secret_version" "huggingface_token_version" {
  secret_id     = aws_secretsmanager_secret.huggingface_token.id
  secret_string = var.huggingface_hub_token // This uses the value from your .tfvars file
}