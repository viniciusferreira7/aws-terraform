# AWS ECS Fargate Infrastructure with Terraform

Production-ready AWS infrastructure for deploying containerized applications using ECS Fargate, Application Load Balancer, and automated CI/CD with GitHub Actions.

## 🏗️ Architecture

```
Internet
    │
    ├─→ Route 53 (optional)
    │
    ├─→ ACM Certificate (HTTPS)
    │
    ├─→ Application Load Balancer (Public Subnets)
    │       ├─ HTTP → HTTPS redirect
    │       └─ HTTPS → ECS Tasks
    │
    └─→ ECS Fargate Tasks (Private Subnets)
            ├─ Auto-scaling (1-4 tasks)
            ├─ CloudWatch Logs
            └─ NAT Gateway → Internet (outbound)

Supporting Infrastructure:
- ECR: Container image registry
- IAM: Task execution and application roles
- Security Groups: ALB and ECS isolation
- DynamoDB: Terraform state locking
```

## 📋 Prerequisites

- **Terraform**: >= 1.5.0
- **AWS CLI**: Configured with credentials
- **Docker**: For building and pushing container images
- **Git**: For version control
- **GitHub Account**: For CI/CD (optional)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd aws-terraform
```

### 2. Configure AWS Profile

Update `variables.tf` or create `terraform.tfvars`:

```hcl
profile = "admin_vinicius_ferreira"  # Your AWS CLI profile
region  = "us-east-1"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Deploy Infrastructure

For development environment:

```bash
# Plan
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars
```

### 5. Build and Push Container Image

```bash
# Get ECR repository URL from Terraform outputs
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

# Build and push
docker build -t my-app .
docker tag my-app:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

### 6. Update Container Image

Update `environments/dev.tfvars`:

```hcl
container_image = "<ecr-repository-url>:latest"
```

Then apply again:

```bash
terraform apply -var-file=environments/dev.tfvars
```

### 7. Access Your Application

```bash
# Get ALB URL
terraform output alb_url
```

Visit the URL in your browser!

## 📁 Project Structure

```
.
├── modules/
│   ├── ecr/              # Container registry
│   ├── networking/       # VPC, subnets, NAT
│   ├── security-groups/  # ALB and ECS security groups
│   ├── iam/             # ECS task roles
│   ├── alb/             # Application Load Balancer
│   └── ecs/             # ECS Fargate cluster and service
├── environments/
│   ├── dev.tfvars       # Development configuration
│   ├── staging.tfvars   # Staging configuration
│   └── prod.tfvars      # Production configuration
├── docs/
│   ├── architecture.md  # Architecture details
│   ├── deployment.md    # Deployment guide
│   └── runbook.md       # Operations runbook
├── .github/
│   └── workflows/
│       └── terraform.yml # CI/CD pipeline
├── main.tf              # Main infrastructure
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Terraform and provider versions
├── locals.tf            # Local values
├── acm.tf              # ACM certificate (optional)
└── iam-github-actions.tf # GitHub OIDC for CI/CD
```

## 🔧 Module Overview

### ECR Module
- Container image registry
- Image scanning enabled
- Lifecycle policy (keep last 10 images)

### Networking Module
- VPC with public and private subnets
- Internet Gateway for public subnets
- NAT Gateway for private subnet outbound traffic
- Multi-AZ deployment (us-east-1a, us-east-1b)

### Security Groups Module
- ALB security group (allow 80/443 from internet)
- ECS security group (allow traffic from ALB only)

### IAM Module
- Task execution role (ECR pull, CloudWatch Logs)
- Task role (application permissions)

### ALB Module
- Internet-facing Application Load Balancer
- HTTP → HTTPS redirect
- Health checks for ECS tasks

### ECS Module
- ECS Fargate cluster
- Task definition with configurable CPU/memory
- ECS service with ALB integration
- Auto-scaling based on CPU and memory
- CloudWatch logging

## 🌍 Environments

### Development (`dev.tfvars`)
- 1 task (256 CPU, 512 MB memory)
- HTTP only (no HTTPS)
- Minimal auto-scaling (1-2 tasks)
- 7-day log retention
- ECS Exec enabled for debugging

### Staging (`staging.tfvars`)
- 2 tasks (512 CPU, 1024 MB memory)
- Optional HTTPS
- Moderate auto-scaling (2-4 tasks)
- 14-day log retention

### Production (`prod.tfvars`)
- 2+ tasks (512 CPU, 1024 MB memory)
- HTTPS required
- Aggressive auto-scaling (2-10 tasks)
- 30-day log retention
- Deletion protection enabled
- ECS Exec disabled

## 🤖 CI/CD with GitHub Actions

### Setup

1. Create GitHub OIDC provider and role:
   ```bash
   # Update iam-github-actions.tf with your GitHub repo
   # Then apply
   terraform apply
   ```

2. Add GitHub secrets:
   - `AWS_REGION`: `us-east-1`
   - `AWS_ROLE_ARN`: (from terraform output)

3. Configure environment protection (Settings > Environments):
   - Create "production" environment
   - Add required reviewers

### Workflow

- **Push to PR**: Runs `terraform fmt`, `validate`, and `plan`
- **Merge to main**: Runs `terraform apply` (requires approval)
- Plan output is posted as PR comment

## 💰 Cost Estimate

Monthly costs (us-east-1, dev environment):

| Resource | Cost |
|----------|------|
| NAT Gateway | ~$32 + data transfer |
| Application Load Balancer | ~$16 + LCU |
| ECS Fargate (1 task, 0.25 vCPU, 0.5 GB) | ~$7.50 |
| CloudWatch Logs | ~$5 |
| ECR Storage | ~$1 |
| **Total** | **~$65-100/month** |

### Cost Optimization

- Use single NAT Gateway (saves ~$32/month)
- Scale down during off-hours
- Reduce log retention
- Right-size tasks based on actual usage
- Consider Fargate Spot for non-critical workloads (70% savings)

## 🔒 Security Best Practices

- ✅ ECS tasks in private subnets (no direct internet access)
- ✅ Security groups with least privilege
- ✅ Separate IAM roles for execution and application
- ✅ Secrets via AWS Secrets Manager
- ✅ ECR image scanning enabled
- ✅ HTTPS with ACM certificates (production)
- ✅ CloudWatch logging enabled
- ✅ State locking with DynamoDB
- ✅ OIDC for GitHub Actions (no hardcoded credentials)

## 📊 Monitoring

### CloudWatch Logs

```bash
# Tail logs
aws logs tail /ecs/dev-app --follow

# Query logs
aws logs filter-log-events \
  --log-group-name /ecs/dev-app \
  --filter-pattern "ERROR"
```

### ECS Service

```bash
# Describe service
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-app-service

# List tasks
aws ecs list-tasks --cluster dev-cluster

# Describe task
aws ecs describe-tasks \
  --cluster dev-cluster \
  --tasks <task-id>
```

### ALB Health

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

## 🐛 Troubleshooting

### Tasks Not Starting

```bash
# Check service events
aws ecs describe-services --cluster <cluster> --services <service>

# Check task stopped reason
aws ecs describe-tasks --cluster <cluster> --tasks <task-id>
```

Common issues:
- Invalid container image
- Insufficient IAM permissions
- Health check failures
- Resource constraints

### Health Check Failures

- Ensure your app responds with HTTP 200 on health check path
- Check application logs in CloudWatch
- Verify security groups allow ALB → ECS traffic
- Increase health check timeout if app is slow to start

### High Costs

- Check CloudWatch metrics for unused resources
- Review auto-scaling settings
- Consider scaling down during off-hours
- Reduce log retention
- Use Fargate Spot for non-critical workloads

## 📚 Additional Resources

- [Architecture Details](./docs/architecture.md)
- [Deployment Guide](./docs/deployment.md)
- [Operations Runbook](./docs/runbook.md)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `terraform fmt -recursive`
5. Submit a pull request

## 📝 License

This project is for educational purposes.

## 👤 Author

Vinicius Ferreira - Rocketseat AWS Study Program

## 🙏 Acknowledgments

- Rocketseat AWS Study Program
- Terraform AWS Provider Team
- AWS Documentation
