provider "aws" {
  region  = var.region
  profile = var.profile
}

# S3 bucket for Terraform state (already exists, managed here)
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "aws-terraform-vinicius-study"
  force_destroy = false # Protect state bucket

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "versioning_terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}

# ECR Module - Container Registry
module "ecr" {
  source = "./modules/ecr"

  repository_name       = local.ecr_repository_name
  enable_image_scanning = true
  image_retention_count = 10

  tags = local.common_tags
}

# Networking Module - VPC, Subnets, NAT
module "networking" {
  source = "./modules/networking"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.common_tags
}

# Security Groups Module - ALB and ECS security groups
module "security_groups" {
  source = "./modules/security-groups"

  environment    = var.environment
  vpc_id         = module.networking.vpc_id
  container_port = var.container_port
  enable_https   = var.enable_https

  tags = local.common_tags
}

# IAM Module - ECS task roles
module "iam" {
  source = "./modules/iam"

  environment              = var.environment
  cloudwatch_log_group_arn = module.ecs.cloudwatch_log_group_arn

  # Optional: Add S3 buckets or secrets your app needs
  app_s3_bucket_arns = var.app_s3_bucket_arns
  app_secrets_arns   = var.app_secrets_arns

  tags = local.common_tags

  depends_on = [module.ecs]
}

# ALB Module - Application Load Balancer
module "alb" {
  source = "./modules/alb"

  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  container_port        = var.container_port

  enable_https               = var.enable_https
  certificate_arn            = var.certificate_arn
  enable_deletion_protection = var.enable_deletion_protection

  health_check_path                = var.health_check_path
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  health_check_interval            = var.health_check_interval
  health_check_matcher             = var.health_check_matcher

  tags = local.common_tags
}

# ECS Module - Fargate cluster and service
module "ecs" {
  source = "./modules/ecs"

  environment  = var.environment
  service_name = local.service_name
  aws_region   = var.region

  # Networking
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id

  # Load Balancer
  target_group_arn = module.alb.target_group_arn
  alb_listener_arn = module.alb.http_listener_arn

  # IAM Roles
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn

  # Container Configuration
  container_name  = var.container_name
  container_image = var.container_image
  container_port  = var.container_port

  # Task Resources
  task_cpu      = var.task_cpu
  task_memory   = var.task_memory
  desired_count = var.desired_count

  # Environment Variables and Secrets
  environment_variables = var.environment_variables
  secrets               = var.secrets

  # Auto-scaling
  autoscaling_min_capacity  = var.autoscaling_min_capacity
  autoscaling_max_capacity  = var.autoscaling_max_capacity
  autoscaling_cpu_target    = var.autoscaling_cpu_target
  autoscaling_memory_target = var.autoscaling_memory_target

  # Monitoring
  enable_container_insights = var.enable_container_insights
  log_retention_days        = var.log_retention_days
  enable_execute_command    = var.enable_execute_command

  tags = local.common_tags
}
