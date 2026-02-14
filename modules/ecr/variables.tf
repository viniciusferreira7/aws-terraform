variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "enable_image_scanning" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "image_retention_count" {
  description = "Number of images to retain in the repository"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to ECR repository"
  type        = map(string)
  default     = {}
}
