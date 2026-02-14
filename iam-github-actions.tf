# GitHub OIDC Provider for GitHub Actions
# This allows GitHub Actions to assume AWS roles without storing AWS credentials

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# OIDC Provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub's OIDC thumbprint
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = local.common_tags
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Replace with your GitHub username/organization and repository
            # Format: "repo:<GITHUB_USERNAME>/<REPO_NAME>:*"
            # Example: "repo:johndoe/aws-terraform:*"
            "token.actions.githubusercontent.com:sub" = "repo:*:*" # CHANGE THIS!
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Policy for GitHub Actions (AdministratorAccess for simplicity)
# For production, scope this down to specific permissions
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# More restrictive policy example (commented out)
# resource "aws_iam_role_policy" "github_actions_terraform" {
#   name = "github-actions-terraform-policy"
#   role = aws_iam_role.github_actions.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ec2:*",
#           "ecs:*",
#           "ecr:*",
#           "elasticloadbalancing:*",
#           "logs:*",
#           "iam:*",
#           "s3:*",
#           "dynamodb:*",
#           "autoscaling:*",
#           "cloudwatch:*",
#           "application-autoscaling:*"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# Outputs
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "aws_account_id" {
  description = "AWS Account ID (needed for GitHub Actions workflow)"
  value       = data.aws_caller_identity.current.account_id
}

output "github_actions_setup_instructions" {
  description = "Instructions for setting up GitHub Actions"
  value       = <<-EOT

    === GitHub Actions Setup Instructions ===

    1. Update the IAM role trust policy in iam-github-actions.tf:
       Change "repo:*:*" to "repo:<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>:*"
       Example: "repo:vinic/aws-terraform:*"

    2. Apply this configuration to create the OIDC provider and role:
       terraform apply

    3. In your GitHub repository, create these secrets:
       - AWS_REGION: ${var.region}
       - AWS_ROLE_ARN: ${aws_iam_role.github_actions.arn}

    4. (Optional) For production environment protection:
       - Go to GitHub repository Settings > Environments
       - Create "production" environment
       - Add required reviewers

    5. The GitHub Actions workflow is ready to use!
       - Push code to trigger the workflow
       - PRs will run terraform plan
       - Merges to main will run terraform apply (with approval for production)

    AWS Account ID: ${data.aws_caller_identity.current.account_id}
    GitHub Actions Role ARN: ${aws_iam_role.github_actions.arn}
  EOT
}
