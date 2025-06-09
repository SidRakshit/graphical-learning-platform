// graphical-learning-platform/terraform/environments/dev/storage.tf

// --- S3 Buckets for ML ---
resource "aws_s3_bucket" "ml_datasets_bucket" {
  bucket = local.actual_ml_datasets_bucket_name

  tags = merge(local.common_tags, {
    Name = local.actual_ml_datasets_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "ml_datasets_bucket_versioning" {
  bucket = aws_s3_bucket.ml_datasets_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_datasets_bucket_sse" {
  bucket = aws_s3_bucket.ml_datasets_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ml_datasets_bucket_pab" {
  bucket                  = aws_s3_bucket.ml_datasets_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "ml_models_bucket" {
  bucket = local.actual_ml_models_bucket_name

  tags = merge(local.common_tags, {
    Name = local.actual_ml_models_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "ml_models_bucket_versioning" {
  bucket = aws_s3_bucket.ml_models_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_models_bucket_sse" {
  bucket = aws_s3_bucket.ml_models_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ml_models_bucket_pab" {
  bucket                  = aws_s3_bucket.ml_models_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// --- VPC S3 Gateway Endpoint ---
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public_rt.id,
    aws_route_table.private_az1_rt.id,
    aws_route_table.private_az2_rt.id
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-s3-gateway-endpoint-${var.environment_name}"
  })
}
