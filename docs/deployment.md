# Deployment Guide

Complete step-by-step guide for deploying the ECS Fargate infrastructure.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.5.0 installed
- [ ] Docker installed
- [ ] Git installed
- [ ] Your application containerized (Dockerfile ready)

## Phase 1: Initial Setup

### Step 1: Clone Repository

```bash
git clone <your-repo-url>
cd aws-terraform
```

### Step 2: Configure AWS Credentials

```bash
# Configure AWS CLI profile
aws configure --profile admin_vinicius_ferreira

# Test credentials
aws sts get-caller-identity --profile admin_vinicius_ferreira
```

### Step 3: Review Configuration

Edit `variables.tf` or create `terraform.tfvars`:

```hcl
profile      = "admin_vinicius_ferreira"
region       = "us-east-1"
environment  = "dev"
project_name = "Terraform Study"
```

## Phase 2: Infrastructure Deployment

### Step 4: Initialize Terraform

```bash
# Initialize Terraform
terraform init

# Expected output:
# - Downloads AWS provider
# - Configures S3 backend
# - Sets up DynamoDB state locking
```

### Step 5: Plan Infrastructure

```bash
# Plan with dev environment
terraform plan -var-file=environments/dev.tfvars

# Review the plan:
# - VPC and subnets
# - Security groups
# - IAM roles
# - ECR repository
# - ALB
# - ECS cluster (but no tasks yet - we need an image first)
```

### Step 6: Apply Infrastructure (First Pass)

```bash
# Apply to create ECR and supporting infrastructure
terraform apply -var-file=environments/dev.tfvars

# Type 'yes' when prompted
```

**Important**: The first apply will create everything except the ECS service will fail to start because we haven't pushed a container image yet. This is expected!

### Step 7: Get Infrastructure Outputs

```bash
# Get all outputs
terraform output

# Get specific outputs
ECR_REPO=$(terraform output -raw ecr_repository_url)
echo "ECR Repository: $ECR_REPO"

# Save the ECR URL - you'll need it next
```

## Phase 3: Container Image

### Step 8: Build Your Container

Create a `Dockerfile` if you don't have one. Example:

```dockerfile
FROM nginx:alpine

# Copy your application
COPY . /usr/share/nginx/html

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1
```

### Step 9: Build and Tag Image

```bash
# Build image
docker build -t my-app .

# Test locally
docker run -p 8080:80 my-app

# Visit http://localhost:8080 to verify
```

### Step 10: Push to ECR

```bash
# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 --profile admin_vinicius_ferreira | \
  docker login --username AWS --password-stdin $ECR_REPO

# Tag image
docker tag my-app:latest $ECR_REPO:latest

# Push image
docker push $ECR_REPO:latest

# Verify image was pushed
aws ecr describe-images \
  --repository-name $(terraform output -raw ecr_repository_name) \
  --profile admin_vinicius_ferreira
```

## Phase 4: Deploy ECS Service

### Step 11: Update Configuration

Edit `environments/dev.tfvars` and add:

```hcl
container_image = "<paste-ecr-repository-url>:latest"
```

Example:
```hcl
container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/dev-terraform-study-app:latest"
```

### Step 12: Deploy ECS Service

```bash
# Plan with container image
terraform plan -var-file=environments/dev.tfvars

# Apply to create ECS service
terraform apply -var-file=environments/dev.tfvars
```

### Step 13: Monitor Deployment

```bash
# Get cluster and service names
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)

# Watch service deployment
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --profile admin_vinicius_ferreira

# Check task status
aws ecs list-tasks \
  --cluster $CLUSTER \
  --profile admin_vinicius_ferreira

# Get task details
TASK_ID=$(aws ecs list-tasks --cluster $CLUSTER --query 'taskArns[0]' --output text --profile admin_vinicius_ferreira)
aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks $TASK_ID \
  --profile admin_vinicius_ferreira
```

### Step 14: Verify Deployment

```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_url)
echo "Application URL: $ALB_URL"

# Test the application
curl $ALB_URL

# Or visit in browser
open $ALB_URL  # macOS
# or
xdg-open $ALB_URL  # Linux
```

### Step 15: Check Application Logs

```bash
# Get log group name
LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name)

# Tail logs
aws logs tail $LOG_GROUP --follow --profile admin_vinicius_ferreira

# Filter for errors
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --filter-pattern "ERROR" \
  --profile admin_vinicius_ferreira
```

## Phase 5: Health Checks

### Step 16: Verify ALB Health

```bash
# Check target health
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)

aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --profile admin_vinicius_ferreira

# Expected output:
# - State: healthy
# - HealthCheckPort: 80
```

### Step 17: Verify Auto-scaling

```bash
# Check auto-scaling configuration
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids "service/$CLUSTER/$SERVICE" \
  --profile admin_vinicius_ferreira

# Check scaling policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id "service/$CLUSTER/$SERVICE" \
  --profile admin_vinicius_ferreira
```

## Troubleshooting Deployment

### Tasks Not Starting

**Symptom**: Tasks start and immediately stop

**Check**:
```bash
# Get stopped tasks
aws ecs list-tasks \
  --cluster $CLUSTER \
  --desired-status STOPPED \
  --profile admin_vinicius_ferreira

# Describe stopped task
aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks <task-id> \
  --profile admin_vinicius_ferreira
```

**Common causes**:
1. Invalid container image
2. Insufficient IAM permissions
3. Application crashes on startup
4. Port mismatch (container_port vs application port)

**Solutions**:
```bash
# Test container locally
docker run -p 8080:80 $ECR_REPO:latest

# Check IAM role permissions
aws iam get-role-policy \
  --role-name dev-ecs-task-execution-role \
  --policy-name dev-ecs-task-execution-ecr-policy \
  --profile admin_vinicius_ferreira
```

### Health Check Failures

**Symptom**: ALB shows targets as unhealthy

**Check**:
```bash
# Get detailed target health
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --profile admin_vinicius_ferreira

# Check application logs
aws logs tail $LOG_GROUP --follow --profile admin_vinicius_ferreira
```

**Common causes**:
1. Application doesn't respond with HTTP 200
2. Application takes too long to start
3. Wrong health check path
4. Security group blocking traffic

**Solutions**:
```bash
# Update health check path in environments/dev.tfvars
health_check_path = "/health"  # Or whatever your app uses

# Apply changes
terraform apply -var-file=environments/dev.tfvars
```

### Access Denied Errors

**Symptom**: Tasks can't pull ECR images or write logs

**Check**:
```bash
# Check CloudWatch logs for permission errors
aws logs tail $LOG_GROUP --profile admin_vinicius_ferreira
```

**Solution**:
```bash
# Verify task execution role has ECR and CloudWatch permissions
# Check modules/iam/main.tf for correct permissions
```

## Deploying to Other Environments

### Staging Environment

```bash
# Update staging configuration
# Edit environments/staging.tfvars with container_image

# Deploy to staging
terraform workspace new staging  # Optional: use workspaces
terraform plan -var-file=environments/staging.tfvars
terraform apply -var-file=environments/staging.tfvars
```

### Production Environment

```bash
# Prerequisites for production:
# 1. ACM certificate created
# 2. Domain configured
# 3. HTTPS enabled

# Update environments/prod.tfvars:
enable_https    = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

# Deploy to production (requires approval in GitHub Actions)
git add .
git commit -m "feat: deploy to production"
git push origin main
```

## Post-Deployment Tasks

### Configure Custom Domain (Optional)

1. Create ACM certificate:
```bash
aws acm request-certificate \
  --domain-name example.com \
  --validation-method DNS \
  --subject-alternative-names "*.example.com" \
  --profile admin_vinicius_ferreira
```

2. Validate certificate (add DNS records)

3. Update `environments/prod.tfvars`:
```hcl
enable_https    = true
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
```

4. Apply changes:
```bash
terraform apply -var-file=environments/prod.tfvars
```

5. Create Route 53 alias record pointing to ALB

### Set Up CloudWatch Alarms

```bash
# Create alarm for high CPU
aws cloudwatch put-metric-alarm \
  --alarm-name ecs-high-cpu \
  --alarm-description "Alert when CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=ServiceName,Value=$SERVICE Name=ClusterName,Value=$CLUSTER \
  --profile admin_vinicius_ferreira
```

### Configure SNS for Alerts

```bash
# Create SNS topic
aws sns create-topic \
  --name ecs-alerts \
  --profile admin_vinicius_ferreira

# Subscribe your email
aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --profile admin_vinicius_ferreira
```

## Updating Your Application

### Deploy New Version

```bash
# 1. Build new version
docker build -t my-app:v2 .

# 2. Tag with version
docker tag my-app:v2 $ECR_REPO:v2

# 3. Push to ECR
docker push $ECR_REPO:v2

# 4. Update environments/dev.tfvars
container_image = "<ecr-repo>:v2"

# 5. Apply changes
terraform apply -var-file=environments/dev.tfvars

# 6. Monitor deployment
aws ecs describe-services --cluster $CLUSTER --services $SERVICE --profile admin_vinicius_ferreira
```

### Rollback

```bash
# Option 1: Update task definition to previous version
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition <previous-task-definition-arn> \
  --profile admin_vinicius_ferreira

# Option 2: Revert Terraform
git revert <commit-hash>
terraform apply -var-file=environments/dev.tfvars
```

## Clean Up

### Destroy Environment

```bash
# Destroy everything
terraform destroy -var-file=environments/dev.tfvars

# Note: S3 state bucket is protected with force_destroy = false
# To delete it, change main.tf and apply first
```

## Next Steps

- Set up CI/CD with GitHub Actions (see [CI/CD Setup](../README.md#cicd-with-github-actions))
- Configure monitoring and alerting
- Implement blue/green deployment
- Add database resources (RDS, ElastiCache)
- Configure WAF for security

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review [Troubleshooting Guide](./runbook.md)
3. Consult [Architecture Documentation](./architecture.md)
