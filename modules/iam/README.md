# IAM Module

This module creates IAM roles for ECS Fargate tasks following the principle of least privilege.

## Roles Created

### 1. ECS Task Execution Role
**Purpose**: Used by ECS service to manage task lifecycle

**Permissions**:
- Pull container images from ECR
- Write logs to CloudWatch Logs
- Get authorization tokens from ECR

**Used by**: ECS service (AWS infrastructure)

### 2. ECS Task Role
**Purpose**: Used by the application running inside the container

**Permissions**:
- Access S3 buckets (configurable)
- Access Secrets Manager secrets (configurable)
- Add custom permissions as needed

**Used by**: Your application code

## Separation of Concerns

```
ECS Task Execution Role          ECS Task Role
(Infrastructure)                 (Application)
        │                               │
        ├─→ Pull ECR images            ├─→ Read S3 buckets
        ├─→ Write CloudWatch logs      ├─→ Access secrets
        └─→ Start/stop containers      └─→ Call external APIs
```

## Usage

```hcl
module "iam" {
  source = "./modules/iam"

  environment              = "production"
  cloudwatch_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/ecs/my-app"

  # Optional: S3 buckets your app needs to access
  app_s3_bucket_arns = [
    "arn:aws:s3:::my-app-uploads/*",
    "arn:aws:s3:::my-app-data/*"
  ]

  # Optional: Secrets your app needs to access
  app_secrets_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-app/db-password-*",
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-app/api-key-*"
  ]

  tags = {
    Project     = "my-project"
    Environment = "production"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | string | - | yes |
| cloudwatch_log_group_arn | ARN of CloudWatch log group | string | - | yes |
| app_s3_bucket_arns | S3 bucket ARNs for app access | list(string) | [] | no |
| app_secrets_arns | Secrets Manager ARNs for app access | list(string) | [] | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| ecs_task_execution_role_arn | ARN of task execution role |
| ecs_task_role_arn | ARN of task role |
| ecs_task_execution_role_name | Name of task execution role |
| ecs_task_role_name | Name of task role |

## Security Best Practices

1. **Least Privilege**: Only grant permissions your application actually needs
2. **Separate Roles**: Infrastructure permissions separate from application permissions
3. **Resource-Specific**: Grant access to specific resources, not wildcards
4. **Audit Regularly**: Review IAM permissions periodically

## Customizing Application Permissions

Edit the `ecs_task_app` policy in `main.tf` to add permissions your application needs:

```hcl
# Example: Add DynamoDB access
{
  Effect = "Allow"
  Action = [
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:Query"
  ]
  Resource = "arn:aws:dynamodb:us-east-1:123456789012:table/my-table"
}
```

## Common Permission Scenarios

### Access RDS Database
```hcl
{
  Effect = "Allow"
  Action = ["rds-db:connect"]
  Resource = "arn:aws:rds-db:us-east-1:123456789012:dbuser:*/app_user"
}
```

### Send SES Emails
```hcl
{
  Effect = "Allow"
  Action = ["ses:SendEmail", "ses:SendRawEmail"]
  Resource = "*"
}
```

### Publish SNS Messages
```hcl
{
  Effect = "Allow"
  Action = ["sns:Publish"]
  Resource = "arn:aws:sns:us-east-1:123456789012:my-topic"
}
```

### Access Parameter Store
```hcl
{
  Effect = "Allow"
  Action = ["ssm:GetParameter", "ssm:GetParameters"]
  Resource = "arn:aws:ssm:us-east-1:123456789012:parameter/my-app/*"
}
```

## Viewing Effective Permissions

Check what permissions are actually granted:

```bash
# List policies attached to execution role
aws iam list-attached-role-policies --role-name prod-ecs-task-execution-role

# List inline policies
aws iam list-role-policies --role-name prod-ecs-task-execution-role

# Get policy details
aws iam get-role-policy --role-name prod-ecs-task-execution-role --policy-name prod-ecs-task-execution-ecr-policy
```
