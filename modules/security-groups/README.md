# Security Groups Module

This module creates security groups for the Application Load Balancer and ECS tasks, following the principle of least privilege.

## Security Model

```
Internet (0.0.0.0/0)
    │
    ├─→ ALB Security Group
    │   ├─ Inbound: 80 (HTTP), 443 (HTTPS)
    │   └─ Outbound: All traffic
    │
    └─→ ECS Security Group
        ├─ Inbound: Container port (from ALB only)
        └─ Outbound: All traffic (ECR, CloudWatch, NAT)
```

## Features

- **ALB Security Group**:
  - Allows HTTP (80) from internet
  - Optionally allows HTTPS (443) from internet
  - Allows all outbound traffic to communicate with ECS tasks

- **ECS Security Group**:
  - Only allows traffic from ALB on the container port
  - Allows all outbound traffic (for ECR pulls, CloudWatch logs, external APIs)
  - Zero direct internet access to ECS tasks

## Usage

```hcl
module "security_groups" {
  source = "./modules/security-groups"

  environment    = "production"
  vpc_id         = module.networking.vpc_id
  container_port = 80
  enable_https   = true

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
| vpc_id | ID of the VPC | string | - | yes |
| container_port | Port on which container listens | number | 80 | no |
| enable_https | Enable HTTPS on ALB | bool | true | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_security_group_id | ID of the ALB security group |
| ecs_security_group_id | ID of the ECS security group |

## Security Best Practices

1. **Principle of Least Privilege**: ECS tasks only accept traffic from ALB, not directly from internet
2. **Network Isolation**: ECS tasks are in private subnets with no public IPs
3. **Controlled Access**: Only ALB is exposed to the internet
4. **Outbound Freedom**: ECS tasks can reach ECR, CloudWatch, and external APIs via NAT Gateway

## Traffic Flow

### Inbound (User Request)
```
User → Internet → ALB (80/443) → ECS Task (container_port)
```

### Outbound (ECS Task)
```
ECS Task → NAT Gateway → Internet
  - ECR: Pull container images
  - CloudWatch: Send logs
  - External APIs: Application dependencies
```

## Customization

For stricter security, you can:
- Restrict outbound traffic from ECS to specific CIDR blocks
- Add additional security groups for database access
- Implement VPC endpoints to avoid NAT Gateway for AWS services

Example with restricted outbound:
```hcl
# Replace the ecs_all egress rule with specific rules
resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow HTTPS for ECR/CloudWatch"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}
```
