# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository for pushing Docker images"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Full URL of the Application Load Balancer"
  value       = module.alb.alb_url
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "ecs_task_definition_family" {
  description = "Family of the ECS task definition"
  value       = module.ecs.task_definition_family
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for ECS logs"
  value       = aws_cloudwatch_log_group.ecs.name
}

# IAM Outputs
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.iam.ecs_task_role_arn
}

# Deployment Information
output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value       = <<-EOT

    === Deployment Instructions ===

    1. Build and push your Docker image:
       aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${module.ecr.repository_url}
       docker build -t ${module.ecr.repository_name} .
       docker tag ${module.ecr.repository_name}:latest ${module.ecr.repository_url}:latest
       docker push ${module.ecr.repository_url}:latest

    2. Update the container_image variable with:
       container_image = "${module.ecr.repository_url}:latest"

    3. Access your application at:
       ${module.alb.alb_url}

    4. View logs:
       aws logs tail ${module.ecs.cloudwatch_log_group_name} --follow

    5. Check ECS service status:
       aws ecs describe-services --cluster ${module.ecs.cluster_name} --services ${module.ecs.service_name}

    === Useful Commands ===

    - List running tasks:
      aws ecs list-tasks --cluster ${module.ecs.cluster_name}

    - Describe a task:
      aws ecs describe-tasks --cluster ${module.ecs.cluster_name} --tasks <task-id>

    - Check ALB target health:
      aws elbv2 describe-target-health --target-group-arn ${module.alb.target_group_arn}

    - Force new deployment:
      aws ecs update-service --cluster ${module.ecs.cluster_name} --service ${module.ecs.service_name} --force-new-deployment
  EOT
}
