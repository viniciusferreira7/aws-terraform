variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for ECS tasks"
  type        = string
}

variable "app_s3_bucket_arns" {
  description = "List of S3 bucket ARNs that the application needs access to"
  type        = list(string)
  default     = []
}

variable "app_secrets_arns" {
  description = "List of Secrets Manager secret ARNs that the application needs access to"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to IAM roles"
  type        = map(string)
  default     = {}
}
