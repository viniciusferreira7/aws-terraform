variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "app"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Networking
variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

# Load Balancer
variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener (for dependency)"
  type        = string
}

# IAM Roles
variable "execution_role_arn" {
  description = "ARN of the task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the task role"
  type        = string
}

# Container Configuration
variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 80
}

# Task Configuration
variable "task_cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory for the task in MB (512, 1024, 2048, etc.)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

# Environment Variables and Secrets
variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets from Secrets Manager or Parameter Store"
  type        = map(string)
  default     = {}
}

# Container Health Check
variable "container_health_check" {
  description = "Container health check configuration"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    startPeriod = number
  })
  default = null
}

# Auto Scaling
variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 4
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80
}

# CloudWatch Logs
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Features
variable "enable_container_insights" {
  description = "Enable Container Insights for the cluster"
  type        = bool
  default     = true
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to ECS resources"
  type        = map(string)
  default     = {}
}
