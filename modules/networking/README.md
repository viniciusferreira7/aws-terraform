# Networking Module

This module creates a production-ready VPC with public and private subnets across multiple availability zones.

## Architecture

```
Internet
    │
    └─→ Internet Gateway
            │
            ├─→ Public Subnet 1 (AZ-a)
            │       └─→ NAT Gateway
            ├─→ Public Subnet 2 (AZ-b)
            │
            └─→ Private Subnets (AZ-a, AZ-b)
                    └─→ NAT Gateway → Internet
```

## Features

- VPC with configurable CIDR block (default: 10.0.0.0/16)
- Public subnets for internet-facing resources (ALB)
- Private subnets for internal resources (ECS tasks)
- Internet Gateway for public subnet internet access
- Single NAT Gateway for private subnet outbound traffic (cost optimization)
- Separate route tables for public and private subnets
- DNS hostnames and DNS support enabled
- Multi-AZ deployment for high availability

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  environment        = "production"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

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
| vpc_cidr | CIDR block for VPC | string | "10.0.0.0/16" | no |
| availability_zones | List of AZs | list(string) | - | yes |
| public_subnet_cidrs | CIDR blocks for public subnets | list(string) | ["10.0.1.0/24", "10.0.2.0/24"] | no |
| private_subnet_cidrs | CIDR blocks for private subnets | list(string) | ["10.0.10.0/24", "10.0.11.0/24"] | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| vpc_cidr | CIDR block of the VPC |
| public_subnet_ids | IDs of public subnets |
| private_subnet_ids | IDs of private subnets |
| internet_gateway_id | ID of the Internet Gateway |
| nat_gateway_id | ID of the NAT Gateway |
| public_route_table_id | ID of the public route table |
| private_route_table_id | ID of the private route table |

## Cost Optimization

This module uses a **single NAT Gateway** to reduce costs (~$32/month savings vs multi-AZ NAT).

**Trade-offs**:
- ✅ Lower cost (one NAT Gateway instead of two)
- ⚠️ Single point of failure for outbound internet traffic from private subnets
- ⚠️ Cross-AZ data transfer charges if resources in AZ-b use NAT in AZ-a

**For production**: Consider adding `enable_nat_gateway_per_az` variable to deploy NAT Gateway per AZ for higher availability.

## Security

- Public subnets: Resources get public IPs and can accept inbound traffic
- Private subnets: No public IPs, outbound only via NAT Gateway
- Recommendation: Deploy ECS tasks in private subnets, ALB in public subnets

## Network Flow

- **Inbound**: Internet → IGW → Public Subnet (ALB) → Private Subnet (ECS)
- **Outbound from Private**: ECS → NAT Gateway → IGW → Internet
- **Outbound from Public**: ALB → IGW → Internet
