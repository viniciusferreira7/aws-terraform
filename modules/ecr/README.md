# ECR Module

This module creates an Amazon Elastic Container Registry (ECR) repository for storing Docker container images.

## Features

- Container image repository with configurable name
- Image scanning on push (enabled by default)
- Lifecycle policy to automatically clean up old images
- Configurable image retention count (default: 10 images)

## Usage

```hcl
module "ecr" {
  source = "./modules/ecr"

  repository_name        = "my-app"
  enable_image_scanning  = true
  image_retention_count  = 10

  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| repository_name | Name of the ECR repository | string | - | yes |
| enable_image_scanning | Enable image scanning on push | bool | true | no |
| image_retention_count | Number of images to retain | number | 10 | no |
| tags | Tags to apply to repository | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| repository_url | URL of the ECR repository |
| repository_arn | ARN of the ECR repository |
| repository_name | Name of the ECR repository |

## Notes

- The lifecycle policy keeps the last N images and expires older ones automatically
- Image scanning helps identify vulnerabilities in container images
- Repository is set to MUTABLE to allow tag updates (use IMMUTABLE for stricter version control)

## Pushing Images

After creating the repository, authenticate and push images:

```bash
# Get login credentials
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <repository-url>

# Tag your image
docker tag my-app:latest <repository-url>:latest

# Push the image
docker push <repository-url>:latest
```
