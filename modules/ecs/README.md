# ECS Module

This module creates an ECS Fargate cluster with service, task definition, auto-scaling, and CloudWatch logging.

## Features

- **ECS Fargate Cluster**: Serverless container orchestration
- **Task Definition**: Configurable CPU/memory, environment variables, secrets
- **ECS Service**: Integration with ALB, deployment circuit breaker
- **Auto-scaling**: CPU and memory-based scaling (1-4 tasks by default)
- **CloudWatch Logs**: Centralized logging with configurable retention
- **Container Insights**: Optional enhanced monitoring
- **ECS Exec**: Optional debugging capability
- **Health Checks**: ALB and optional container-level health checks

## Architecture

```
ECS Cluster
    │
    └─→ ECS Service (Fargate)
            ├─→ Task Definition
            │       ├─ Container (from ECR)
            │       ├─ CPU/Memory allocation
            │       ├─ Environment variables
            │       └─ Secrets (Secrets Manager)
            │
            ├─→ Tasks (1-4, auto-scaled)
            │       └─→ Private Subnets
            │
            ├─→ CloudWatch Logs
            │       └─ 7-day retention
            │
            └─→ Auto-scaling Policies
                    ├─ CPU target: 70%
                    └─ Memory target: 80%
```

## Usage

```hcl
module "ecs" {
  source = "./modules/ecs"

  environment           = "production"
  service_name          = "my-app"
  aws_region            = "us-east-1"

  # Networking
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id

  # Load Balancer
  target_group_arn      = module.alb.target_group_arn
  alb_listener_arn      = module.alb.http_listener_arn

  # IAM
  execution_role_arn    = module.iam.ecs_task_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn

  # Container
  container_name        = "app"
  container_image       = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest"
  container_port        = 80

  # Task resources
  task_cpu              = 512
  task_memory           = 1024
  desired_count         = 2

  # Environment variables
  environment_variables = {
    APP_ENV   = "production"
    LOG_LEVEL = "info"
  }

  # Secrets from Secrets Manager
  secrets = {
    DATABASE_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-url-xxx"
    API_KEY      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:api-key-xxx"
  }

  # Auto-scaling
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 10
  autoscaling_cpu_target   = 70
  autoscaling_memory_target = 80

  # Monitoring
  enable_container_insights = true
  log_retention_days        = 30

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
| service_name | Name of ECS service | string | "app" | no |
| aws_region | AWS region | string | "us-east-1" | no |
| private_subnet_ids | Private subnet IDs | list(string) | - | yes |
| ecs_security_group_id | ECS security group ID | string | - | yes |
| target_group_arn | Target group ARN | string | - | yes |
| alb_listener_arn | ALB listener ARN | string | - | yes |
| execution_role_arn | Task execution role ARN | string | - | yes |
| task_role_arn | Task role ARN | string | - | yes |
| container_name | Container name | string | "app" | no |
| container_image | Docker image | string | - | yes |
| container_port | Container port | number | 80 | no |
| task_cpu | CPU units | number | 256 | no |
| task_memory | Memory in MB | number | 512 | no |
| desired_count | Desired task count | number | 2 | no |
| environment_variables | Environment variables | map(string) | {} | no |
| secrets | Secrets ARNs | map(string) | {} | no |
| container_health_check | Health check config | object | null | no |
| autoscaling_min_capacity | Min tasks | number | 1 | no |
| autoscaling_max_capacity | Max tasks | number | 4 | no |
| autoscaling_cpu_target | CPU target % | number | 70 | no |
| autoscaling_memory_target | Memory target % | number | 80 | no |
| log_retention_days | Log retention days | number | 7 | no |
| enable_container_insights | Enable insights | bool | true | no |
| enable_execute_command | Enable ECS Exec | bool | false | no |
| tags | Tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ECS cluster ID |
| cluster_name | ECS cluster name |
| cluster_arn | ECS cluster ARN |
| service_id | ECS service ID |
| service_name | ECS service name |
| task_definition_arn | Task definition ARN |
| task_definition_family | Task definition family |
| cloudwatch_log_group_name | Log group name |
| cloudwatch_log_group_arn | Log group ARN |
| autoscaling_target_resource_id | Autoscaling resource ID |

## Fargate CPU/Memory Combinations

Valid combinations for `task_cpu` and `task_memory`:

| CPU (units) | Memory (MB) |
|-------------|-------------|
| 256 | 512, 1024, 2048 |
| 512 | 1024, 2048, 3072, 4096 |
| 1024 | 2048, 3072, 4096, 5120, 6144, 7168, 8192 |
| 2048 | 4096 to 16384 (1GB increments) |
| 4096 | 8192 to 30720 (1GB increments) |

## Auto-scaling

Auto-scaling is based on:
- **CPU**: Scales out when CPU > 70%, scales in when < 70%
- **Memory**: Scales out when Memory > 80%, scales in when < 80%

**Cooldown Periods**:
- Scale out: 60 seconds
- Scale in: 300 seconds (5 minutes)

## Deployment

The service uses **rolling deployment** with:
- **Maximum**: 200% (can run double the desired count during deployment)
- **Minimum**: 100% (always keep desired count running)
- **Circuit Breaker**: Automatically rolls back failed deployments

## Container Health Check

Optional container-level health check:

```hcl
container_health_check = {
  command     = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
  interval    = 30
  timeout     = 5
  retries     = 3
  startPeriod = 60
}
```

## CloudWatch Logs

Logs are sent to `/ecs/{environment}-{service_name}` with:
- **Stream prefix**: `ecs`
- **Retention**: Configurable (default 7 days)

View logs:
```bash
aws logs tail /ecs/prod-my-app --follow
```

## ECS Exec (Debugging)

Enable `enable_execute_command = true` to debug containers:

```bash
aws ecs execute-command \
  --cluster prod-cluster \
  --task <task-id> \
  --container app \
  --interactive \
  --command "/bin/sh"
```

## Container Insights

When enabled, provides enhanced metrics:
- Task-level CPU and memory
- Network metrics
- Storage metrics

View in CloudWatch Container Insights dashboard.

## Secrets Management

Use AWS Secrets Manager or Systems Manager Parameter Store:

```hcl
secrets = {
  DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-pass-xxx"
  API_KEY     = "arn:aws:ssm:us-east-1:123456789012:parameter/api-key"
}
```

Secrets are injected as environment variables at container startup.

## Monitoring

Key metrics to monitor:
- CPU utilization
- Memory utilization
- Task count
- ALB target health
- Deployment success/failure

## Troubleshooting

### Tasks not starting
```bash
# Check service events
aws ecs describe-services --cluster <cluster> --services <service>

# Check task stopped reason
aws ecs describe-tasks --cluster <cluster> --tasks <task-id>
```

### Health check failures
```bash
# View target health
aws elbv2 describe-target-health --target-group-arn <arn>

# Check application logs
aws logs tail /ecs/prod-app --follow
```

### High CPU/Memory
```bash
# View Container Insights
# Or check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=<service> \
  --start-time <timestamp> \
  --end-time <timestamp> \
  --period 300 \
  --statistics Average
```

## Cost Optimization

- **Right-size tasks**: Start small, monitor, then increase
- **Use Fargate Spot**: Up to 70% savings (add capacity provider)
- **Reduce log retention**: Lower retention = lower costs
- **Scale down off-hours**: Use scheduled scaling

## Best Practices

1. Always use specific image tags (not `latest`)
2. Set appropriate health check paths
3. Configure auto-scaling based on actual load
4. Use secrets for sensitive data
5. Enable Container Insights for production
6. Set appropriate log retention
7. Use deployment circuit breaker
8. Monitor CloudWatch alarms
