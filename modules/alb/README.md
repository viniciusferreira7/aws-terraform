# Application Load Balancer Module

This module creates an Application Load Balancer (ALB) with target group and listeners for HTTP/HTTPS traffic.

## Features

- Internet-facing Application Load Balancer
- Target group with IP target type (required for Fargate)
- HTTP listener (redirect to HTTPS or forward to target group)
- Optional HTTPS listener with ACM certificate
- Configurable health checks
- Cross-zone load balancing enabled
- HTTP/2 support enabled

## Architecture

```
Internet
    │
    ├─→ HTTP (80) ──→ Redirect to HTTPS (443)
    │
    └─→ HTTPS (443) ──→ Target Group ──→ ECS Tasks
```

## Usage

### Without HTTPS (Development)
```hcl
module "alb" {
  source = "./modules/alb"

  environment            = "dev"
  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  alb_security_group_id  = module.security_groups.alb_security_group_id
  container_port         = 80
  enable_https           = false

  health_check_path      = "/"
  health_check_matcher   = "200"

  tags = {
    Environment = "dev"
  }
}
```

### With HTTPS (Production)
```hcl
module "alb" {
  source = "./modules/alb"

  environment               = "production"
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  alb_security_group_id     = module.security_groups.alb_security_group_id
  container_port            = 80
  enable_https              = true
  certificate_arn           = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
  enable_deletion_protection = true

  health_check_path         = "/health"
  health_check_matcher      = "200,201"

  tags = {
    Environment = "production"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | string | - | yes |
| vpc_id | ID of the VPC | string | - | yes |
| public_subnet_ids | List of public subnet IDs | list(string) | - | yes |
| alb_security_group_id | Security group ID for ALB | string | - | yes |
| container_port | Container port | number | 80 | no |
| enable_https | Enable HTTPS listener | bool | false | no |
| certificate_arn | ACM certificate ARN | string | "" | no |
| ssl_policy | SSL policy for HTTPS | string | "ELBSecurityPolicy-TLS13-1-2-2021-06" | no |
| enable_deletion_protection | Enable deletion protection | bool | false | no |
| health_check_path | Health check path | string | "/" | no |
| health_check_healthy_threshold | Healthy threshold | number | 3 | no |
| health_check_unhealthy_threshold | Unhealthy threshold | number | 3 | no |
| health_check_timeout | Timeout in seconds | number | 5 | no |
| health_check_interval | Interval in seconds | number | 30 | no |
| health_check_matcher | HTTP status codes | string | "200" | no |
| tags | Tags to apply | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_arn | ARN of the ALB |
| alb_dns_name | DNS name of the ALB |
| alb_zone_id | Zone ID of the ALB |
| target_group_arn | ARN of the target group |
| target_group_name | Name of the target group |
| http_listener_arn | ARN of HTTP listener |
| https_listener_arn | ARN of HTTPS listener |
| alb_url | Full URL of the ALB |

## Health Checks

The target group performs health checks on ECS tasks:

- **Path**: Configurable (default: `/`)
- **Healthy Threshold**: 3 consecutive successes
- **Unhealthy Threshold**: 3 consecutive failures
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Expected Status**: HTTP 200 (configurable)

**Important**: Ensure your application responds with HTTP 200 on the health check path.

## SSL/TLS Configuration

When HTTPS is enabled:
- Uses ACM certificate for SSL/TLS
- Default SSL policy: `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.3 and 1.2)
- HTTP automatically redirects to HTTPS (301 permanent redirect)

### Creating ACM Certificate

```bash
# Request certificate (requires DNS validation)
aws acm request-certificate \
  --domain-name example.com \
  --validation-method DNS \
  --subject-alternative-names "*.example.com"

# Or use Terraform
resource "aws_acm_certificate" "app" {
  domain_name       = "example.com"
  validation_method = "DNS"

  subject_alternative_names = ["*.example.com"]

  lifecycle {
    create_before_destroy = true
  }
}
```

## Target Group Settings

- **Target Type**: IP (required for Fargate)
- **Deregistration Delay**: 30 seconds
- **Protocol**: HTTP
- **Port**: Matches container port

## Monitoring

View ALB metrics in CloudWatch:
- Target response time
- Request count
- HTTP 4xx/5xx errors
- Active connection count
- Healthy/unhealthy host count

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

## Cost

- **ALB**: ~$16/month + LCU charges
- **LCU charges**: Based on traffic (connections, requests, bandwidth)
- **Data transfer**: Standard AWS data transfer rates

## Best Practices

1. **Use HTTPS in Production**: Always enable HTTPS for production
2. **Enable Deletion Protection**: Prevent accidental deletion in production
3. **Configure Health Checks**: Match your application's actual health endpoint
4. **Monitor Metrics**: Set up CloudWatch alarms for errors and latency
5. **Use Latest SSL Policy**: Keep SSL policy updated for security
