variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 80
}

variable "enable_https" {
  description = "Enable HTTPS (port 443) on ALB security group"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to security groups"
  type        = map(string)
  default     = {}
}
