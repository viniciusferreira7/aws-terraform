# Architecture Documentation

## Overview

This document describes the architecture decisions, design patterns, and rationale behind the ECS Fargate infrastructure.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ HTTPS/HTTP
                  │
        ┌─────────▼──────────┐
        │  Route 53 (optional)│
        │   Domain: app.com   │
        └─────────┬───────────┘
                  │
        ┌─────────▼──────────┐
        │  ACM Certificate    │
        │  SSL/TLS for HTTPS  │
        └─────────┬───────────┘
                  │
        ┌─────────▼──────────┐
        │ Application Load   │
        │    Balancer        │
        │  - Port 80 → 443   │
        │  - Port 443 → ECS  │
        └─────────┬───────────┘
                  │
    ┌─────────────┴─────────────┐
    │      Public Subnets       │
    │  10.0.1.0/24 (AZ-a)       │
    │  10.0.2.0/24 (AZ-b)       │
    └───────────────────────────┘
                  │
                  │ Target Group (IP)
                  │
    ┌─────────────▼─────────────┐
    │     Private Subnets       │
    │  10.0.10.0/24 (AZ-a)      │
    │  10.0.11.0/24 (AZ-b)      │
    │                           │
    │  ┌─────────────────────┐  │
    │  │   ECS Fargate       │  │
    │  │   - Task 1 (AZ-a)   │  │
    │  │   - Task 2 (AZ-b)   │  │
    │  │   - Auto-scaling    │  │
    │  └──────────┬──────────┘  │
    │             │              │
    │             │ Logs         │
    │  ┌──────────▼──────────┐  │
    │  │  CloudWatch Logs    │  │
    │  └─────────────────────┘  │
    └───────────┬───────────────┘
                │
                │ Outbound (NAT)
                │
      ┌─────────▼─────────┐
      │   NAT Gateway     │
      │   Public Subnet   │
      └─────────┬─────────┘
                │
      ┌─────────▼─────────┐
      │ Internet Gateway  │
      └───────────────────┘

Supporting Services:
├── ECR: Container Registry
├── IAM: Roles & Policies
├── S3: Terraform State
├── DynamoDB: State Locking
└── CloudWatch: Monitoring & Alarms
```

## Network Architecture

### VPC Design

- **CIDR Block**: 10.0.0.0/16 (65,536 IP addresses)
- **Subnets**: Multi-AZ deployment across 2 availability zones
- **Public Subnets**: For internet-facing resources (ALB)
- **Private Subnets**: For internal resources (ECS tasks)

### Subnet Design

| Subnet Type | CIDR | AZ | Purpose |
|-------------|------|----|----|
| Public-1 | 10.0.1.0/24 | us-east-1a | ALB, NAT Gateway |
| Public-2 | 10.0.2.0/24 | us-east-1b | ALB (multi-AZ) |
| Private-1 | 10.0.10.0/24 | us-east-1a | ECS tasks |
| Private-2 | 10.0.11.0/24 | us-east-1b | ECS tasks |

### Routing

**Public Subnets**:
- Default route → Internet Gateway
- Direct internet access (bidirectional)

**Private Subnets**:
- Default route → NAT Gateway
- Outbound internet access only
- No inbound from internet

## Security Architecture

### Network Security Layers

1. **Internet → ALB**: Public internet access on ports 80/443
2. **ALB → ECS**: Only ALB can reach ECS tasks on container port
3. **ECS → Internet**: Outbound only via NAT Gateway
4. **ECS → AWS Services**: Via NAT Gateway or VPC Endpoints (optional)

### Security Groups

#### ALB Security Group
```
Inbound:
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 443 (HTTPS) from 0.0.0.0/0

Outbound:
  - All traffic to 0.0.0.0/0
```

#### ECS Security Group
```
Inbound:
  - Container port from ALB security group only

Outbound:
  - All traffic to 0.0.0.0/0 (for ECR, CloudWatch, external APIs)
```

### IAM Security Model

#### Task Execution Role
- **Purpose**: ECS service infrastructure operations
- **Permissions**:
  - Pull images from ECR
  - Write logs to CloudWatch
  - Get secrets from Secrets Manager (if configured)

#### Task Role
- **Purpose**: Application permissions
- **Permissions**: Customizable based on application needs
  - S3 bucket access
  - DynamoDB access
  - Secrets Manager access
  - etc.

### Defense in Depth

1. **Network Isolation**: ECS tasks in private subnets
2. **Security Groups**: Least privilege network access
3. **IAM Roles**: Least privilege AWS API access
4. **Secrets Management**: No hardcoded credentials
5. **Image Scanning**: ECR scans for vulnerabilities
6. **Encryption**: HTTPS with ACM certificates
7. **State Security**: S3 encryption, DynamoDB locking

## Compute Architecture

### ECS Fargate

**Why Fargate?**
- ✅ No EC2 instance management
- ✅ Pay only for what you use
- ✅ Automatic scaling
- ✅ Better security isolation
- ✅ Simplified operations

**vs. EC2 Launch Type**:
- ❌ Slightly higher cost per task
- ❌ Less control over underlying infrastructure
- ✅ But: Easier to manage, more secure

### Task Definition

- **Network Mode**: `awsvpc` (required for Fargate)
- **CPU/Memory**: Right-sized based on environment
- **Container**: Single container per task (microservice pattern)
- **Logging**: CloudWatch Logs driver
- **Health Checks**: Container-level and ALB-level

### Auto-scaling

**Metrics**:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)

**Configuration**:
- Min: 1-2 tasks (based on environment)
- Max: 2-10 tasks (based on environment)
- Scale-out cooldown: 60 seconds
- Scale-in cooldown: 300 seconds

**Why these settings?**
- Quick scale-out for traffic spikes
- Slow scale-in to avoid flapping

## Load Balancing

### Application Load Balancer

**Why ALB vs NLB?**
- ✅ Layer 7 (HTTP/HTTPS) routing
- ✅ Host-based and path-based routing
- ✅ WebSocket support
- ✅ Better for HTTP workloads
- ❌ Higher cost than NLB
- ❌ Not suitable for non-HTTP protocols

### Target Group

- **Target Type**: IP (required for Fargate)
- **Protocol**: HTTP
- **Health Check**:
  - Path: `/` (configurable)
  - Interval: 30 seconds
  - Healthy threshold: 3
  - Unhealthy threshold: 3

### Deployment Strategy

- **Type**: Rolling deployment
- **Maximum**: 200% (can run double capacity during deployment)
- **Minimum**: 100% (always maintain desired capacity)
- **Circuit Breaker**: Enabled (automatic rollback on failure)

## Storage and State

### Container Registry (ECR)

- **Image Scanning**: Enabled on push
- **Lifecycle Policy**: Keep last 10 images
- **Encryption**: At rest (default AWS encryption)

### Terraform State

- **Backend**: S3 with DynamoDB locking
- **Bucket**: `aws-terraform-vinicius-study`
- **Versioning**: Enabled
- **Locking**: DynamoDB table prevents concurrent modifications

### Application Data

Not included in this infrastructure, but recommendations:
- **RDS**: For relational databases
- **ElastiCache**: For caching
- **S3**: For file storage
- **DynamoDB**: For NoSQL data

## Monitoring and Observability

### CloudWatch Logs

- **Log Group**: `/ecs/{environment}-{service}`
- **Retention**: 7-30 days (based on environment)
- **Streams**: One per task

### Container Insights

When enabled:
- Task-level CPU and memory
- Network metrics
- Storage metrics
- Performance analysis

### Metrics to Monitor

1. **ECS Service**:
   - CPU utilization
   - Memory utilization
   - Task count
   - Deployment success rate

2. **ALB**:
   - Request count
   - Response time
   - HTTP 4xx/5xx errors
   - Target health

3. **Auto-scaling**:
   - Scale-out events
   - Scale-in events
   - Throttling

## Cost Optimization

### Single NAT Gateway

**Decision**: Use 1 NAT Gateway instead of 2

**Pros**:
- Save ~$32/month

**Cons**:
- Single point of failure for outbound traffic
- Cross-AZ data transfer charges

**Recommendation**:
- Dev/Staging: Single NAT
- Production: Consider multi-AZ NAT for high availability

### Fargate Pricing

**Cost Factors**:
- vCPU hours
- Memory GB hours

**Optimization**:
- Right-size tasks (start small, monitor, adjust)
- Use auto-scaling (don't over-provision)
- Consider Fargate Spot (up to 70% savings)

### Resource Right-sizing

| Environment | CPU | Memory | Cost/month (1 task) |
|-------------|-----|--------|---------------------|
| Dev | 256 | 512 MB | ~$7.50 |
| Staging | 512 | 1024 MB | ~$15 |
| Prod | 512 | 1024 MB | ~$15 (x2 tasks = $30) |

## High Availability

### Multi-AZ Deployment

- ECS tasks spread across 2 AZs
- ALB spans multiple AZs
- If one AZ fails, traffic routes to healthy AZ

### Failure Scenarios

| Failure | Impact | Mitigation |
|---------|--------|-----------|
| Task crash | Auto-replaced by ECS | Deployment circuit breaker |
| AZ failure | Traffic routes to other AZ | Multi-AZ deployment |
| NAT Gateway failure | No outbound from private subnets | Add second NAT (production) |
| ALB failure | No incoming traffic | AWS-managed, multi-AZ by default |

### RTO and RPO

- **RTO** (Recovery Time Objective): ~5 minutes
  - ECS starts new task in < 5 minutes
- **RPO** (Recovery Point Objective): 0 (stateless containers)

## Scalability

### Horizontal Scaling

- **Current**: 1-10 tasks (configurable)
- **Limit**: 1000+ tasks per cluster (AWS limit)
- **Auto-scaling**: Based on CPU and memory

### Vertical Scaling

- Increase CPU/memory per task
- Update task definition
- Deploy new version

### Scaling Considerations

- Cold start time: ~30-60 seconds per task
- ALB draining: 30 seconds deregistration delay
- Database connections: Use connection pooling

## Design Decisions

### Why Modules?

- ✅ Reusability across environments
- ✅ Easier testing and validation
- ✅ Clear separation of concerns
- ✅ Better documentation

### Why Single Container per Task?

- ✅ Easier to scale independently
- ✅ Simpler deployment
- ✅ Better resource isolation
- ❌ More tasks = slightly higher cost

### Why Not EKS?

- ✅ ECS is simpler for simple workloads
- ✅ Lower operational overhead
- ✅ Tighter AWS integration
- ❌ EKS better for complex microservices

### Why CloudWatch over ELK/Prometheus?

- ✅ Native AWS integration
- ✅ No infrastructure to manage
- ✅ Pay-per-use pricing
- ❌ More expensive at scale
- ❌ Less flexible than self-hosted

## Future Enhancements

### Short-term

1. **VPC Endpoints**: Reduce NAT Gateway costs
2. **WAF**: Add Web Application Firewall
3. **CloudWatch Alarms**: Automated alerting
4. **Route 53**: Custom domain management

### Long-term

1. **Blue/Green Deployment**: Zero-downtime deployments
2. **Service Mesh**: Advanced traffic management
3. **Multi-region**: Disaster recovery
4. **CDN**: CloudFront for static assets

## References

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
