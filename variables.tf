# AWS Configuration
variable "profile" {
  type        = string
  default     = "admin_vinicius_ferreira"
  description = "AWS profile configured in CLI"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (dev, staging, prod)"
}

variable "project_name" {
  type        = string
  default     = "Terraform Study"
  description = "Project name for tagging"
}

# Networking Configuration
variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for VPC"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "Availability zones for multi-AZ deployment"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "CIDR blocks for public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
  description = "CIDR blocks for private subnets"
}

# Container Configuration
variable "container_name" {
  type        = string
  default     = "app"
  description = "Name of the container"
}

variable "container_image" {
  type        = string
  description = "Docker image to deploy (from ECR)"
  # Example: "123456789012.dkr.ecr.us-east-1.amazonaws.com/dev-terraform-study-app:latest"
}

variable "container_port" {
  type        = number
  default     = 80
  description = "Port on which the container listens"
}

# ECS Task Configuration
variable "task_cpu" {
  type        = number
  default     = 256
  description = "CPU units for Fargate task (256, 512, 1024, 2048, 4096)"
}

variable "task_memory" {
  type        = number
  default     = 512
  description = "Memory for Fargate task in MB (512, 1024, 2048, etc.)"
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Desired number of ECS tasks"
}

# Auto-scaling Configuration
variable "autoscaling_min_capacity" {
  type        = number
  default     = 1
  description = "Minimum number of tasks for auto-scaling"
}

variable "autoscaling_max_capacity" {
  type        = number
  default     = 4
  description = "Maximum number of tasks for auto-scaling"
}

variable "autoscaling_cpu_target" {
  type        = number
  default     = 70
  description = "Target CPU utilization percentage for auto-scaling"
}

variable "autoscaling_memory_target" {
  type        = number
  default     = 80
  description = "Target memory utilization percentage for auto-scaling"
}

# Load Balancer Configuration
variable "enable_https" {
  type        = bool
  default     = false
  description = "Enable HTTPS listener on ALB"
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = "ARN of ACM certificate for HTTPS (required if enable_https is true)"
}

variable "enable_deletion_protection" {
  type        = bool
  default     = false
  description = "Enable deletion protection on ALB (recommended for production)"
}

# Health Check Configuration
variable "health_check_path" {
  type        = string
  default     = "/"
  description = "Path for ALB health checks"
}

variable "health_check_healthy_threshold" {
  type        = number
  default     = 3
  description = "Number of consecutive successful health checks required"
}

variable "health_check_unhealthy_threshold" {
  type        = number
  default     = 3
  description = "Number of consecutive failed health checks required"
}

variable "health_check_interval" {
  type        = number
  default     = 30
  description = "Interval between health checks in seconds"
}

variable "health_check_matcher" {
  type        = string
  default     = "200"
  description = "HTTP status codes to consider healthy"
}

# Application Configuration
variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Environment variables for the container"
  # Example:
  # {
  #   APP_ENV   = "production"
  #   LOG_LEVEL = "info"
  # }
}

variable "secrets" {
  type        = map(string)
  default     = {}
  description = "Secrets from AWS Secrets Manager or Parameter Store"
  # Example:
  # {
  #   DATABASE_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-url-xxx"
  #   API_KEY      = "arn:aws:ssm:us-east-1:123456789012:parameter/api-key"
  # }
}

# IAM Configuration
variable "app_s3_bucket_arns" {
  type        = list(string)
  default     = []
  description = "S3 bucket ARNs that the application needs access to"
  # Example: ["arn:aws:s3:::my-bucket/*"]
}

variable "app_secrets_arns" {
  type        = list(string)
  default     = []
  description = "Secrets Manager secret ARNs that the application needs access to"
  # Example: ["arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret-*"]
}

# Monitoring Configuration
variable "enable_container_insights" {
  type        = bool
  default     = true
  description = "Enable Container Insights for enhanced monitoring"
}

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "CloudWatch log retention in days"
}

variable "enable_execute_command" {
  type        = bool
  default     = false
  description = "Enable ECS Exec for debugging containers"
}
