locals {
  # Common tags applied to all resources
  common_tags = {
    IAC         = "Terraform"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Naming convention
  name_prefix = "${var.environment}-${replace(lower(var.project_name), " ", "-")}"

  # ECR repository name
  ecr_repository_name = "${local.name_prefix}-app"

  # Service name for ECS
  service_name = "app"
}
