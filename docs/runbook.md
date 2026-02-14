# Operations Runbook

Day-to-day operations, troubleshooting procedures, and emergency response guide.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Monitoring](#monitoring)
3. [Troubleshooting](#troubleshooting)
4. [Emergency Procedures](#emergency-procedures)
5. [Maintenance](#maintenance)
6. [Common Tasks](#common-tasks)

## Daily Operations

### Health Check Routine

```bash
# Set environment variables
export CLUSTER=$(terraform output -raw ecs_cluster_name)
export SERVICE=$(terraform output -raw ecs_service_name)
export TARGET_GROUP=$(terraform output -raw target_group_arn)
export PROFILE="admin_vinicius_ferreira"

# 1. Check ECS service status
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --profile $PROFILE \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}'

# 2. Check running tasks
aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --profile $PROFILE

# 3. Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP \
  --profile $PROFILE

# 4. Check for recent errors in logs
aws logs filter-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --profile $PROFILE
```

### Metrics to Monitor

**ECS Service**:
- Running vs Desired task count
- CPU utilization < 70%
- Memory utilization < 80%
- No deployment failures

**ALB**:
- All targets healthy
- HTTP 5xx errors < 1%
- Response time < 500ms

**Auto-scaling**:
- Scaling activities (check for thrashing)
- Current capacity within limits

## Monitoring

### CloudWatch Dashboards

Create a custom dashboard:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name ECS-Monitoring \
  --dashboard-body file://dashboard.json \
  --profile $PROFILE
```

Dashboard JSON example:
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", {"stat": "Average"}],
          [".", "MemoryUtilization"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "ECS Resource Utilization"
      }
    }
  ]
}
```

### CloudWatch Alarms

**Critical Alarms**:

```bash
# High CPU (> 80%)
aws cloudwatch put-metric-alarm \
  --alarm-name "$SERVICE-high-cpu" \
  --alarm-description "CPU utilization > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=ServiceName,Value=$SERVICE Name=ClusterName,Value=$CLUSTER

# High Memory (> 85%)
aws cloudwatch put-metric-alarm \
  --alarm-name "$SERVICE-high-memory" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=ServiceName,Value=$SERVICE Name=ClusterName,Value=$CLUSTER

# Unhealthy Targets
aws cloudwatch put-metric-alarm \
  --alarm-name "$SERVICE-unhealthy-targets" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Maximum \
  --period 60 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=TargetGroup,Value=$TARGET_GROUP

# High HTTP 5xx Errors
aws cloudwatch put-metric-alarm \
  --alarm-name "$SERVICE-http-5xx-errors" \
  --metric-name HTTPCode_Target_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_arn)
```

### Log Analysis

**Search for errors**:
```bash
aws logs filter-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '24 hours ago' +%s)000
```

**Search for specific pattern**:
```bash
aws logs filter-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --filter-pattern "timeout" \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

**Tail logs in real-time**:
```bash
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
```

## Troubleshooting

### Problem: Tasks Keep Restarting

**Symptoms**:
- Tasks start and immediately stop
- Desired count not reached
- Service events show task failures

**Investigation**:
```bash
# 1. Get recent stopped tasks
aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --desired-status STOPPED \
  --max-results 5

# 2. Describe stopped task
TASK_ID=<task-id-from-above>
aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks $TASK_ID

# 3. Check logs for that task
aws logs get-log-events \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --log-stream-name "ecs/app/$TASK_ID"
```

**Common Causes**:
1. Application crashes on startup
2. Health check failures
3. Insufficient memory (OOMKilled)
4. Invalid environment variables

**Solutions**:
```bash
# Test container locally
docker run -p 8080:80 $(terraform output -raw ecr_repository_url):latest

# Increase memory if OOMKilled
# Edit environments/dev.tfvars
task_memory = 1024  # Increase from 512

# Apply changes
terraform apply -var-file=environments/dev.tfvars
```

### Problem: High CPU Usage

**Symptoms**:
- CPU utilization > 80%
- Slow response times
- Tasks auto-scaling to maximum

**Investigation**:
```bash
# Check CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$SERVICE Name=ClusterName,Value=$CLUSTER \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

**Solutions**:
1. **Increase task count**:
```bash
# Temporarily increase desired count
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --desired-count 4
```

2. **Increase task CPU**:
```hcl
# Edit environments/dev.tfvars
task_cpu    = 512   # Increase from 256
task_memory = 1024  # Must increase memory too
```

3. **Optimize application**:
- Profile the application
- Identify bottlenecks
- Optimize code

### Problem: Deployment Failures

**Symptoms**:
- Deployment stuck in progress
- Circuit breaker triggered
- Rollback occurring

**Investigation**:
```bash
# Check service events
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].events[0:10]'

# Check task definition
aws ecs describe-task-definition \
  --task-definition $(terraform output -raw ecs_task_definition_family)
```

**Common Causes**:
1. New image is broken
2. Health checks failing
3. Resource constraints

**Solutions**:
```bash
# 1. Rollback to previous task definition
PREVIOUS_TASK_DEF="<previous-task-definition-arn>"
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition $PREVIOUS_TASK_DEF

# 2. Or rollback via Terraform
git revert HEAD
terraform apply -var-file=environments/dev.tfvars
```

### Problem: Cannot Connect to Application

**Symptoms**:
- ALB returns 503 or 504
- "Service Unavailable" error
- Timeout errors

**Investigation**:
```bash
# 1. Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP

# 2. Check security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id) $(terraform output -raw ecs_security_group_id)

# 3. Test from within VPC (if you have a bastion)
# ssh to bastion
curl http://<ecs-task-private-ip>:80
```

**Solutions**:
1. **No healthy targets**: Check task health and logs
2. **Security group issue**: Verify ALB → ECS security group rules
3. **Health check path wrong**: Update `health_check_path` variable

### Problem: High Costs

**Investigation**:
```bash
# Check AWS Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 month ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Check NAT Gateway data transfer
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=$(terraform output -raw nat_gateway_id) \
  --start-time $(date -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

**Solutions**:
- Reduce log retention: `log_retention_days = 7`
- Use VPC endpoints to reduce NAT Gateway usage
- Right-size tasks (reduce CPU/memory)
- Use Fargate Spot for non-production

## Emergency Procedures

### Emergency: Complete Outage

**Immediate Actions**:

1. **Check if it's AWS-wide**:
   - Visit https://health.aws.amazon.com/health/status

2. **Scale to zero** (if application is causing issues):
```bash
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --desired-count 0
```

3. **Check recent changes**:
```bash
git log --oneline -10
```

4. **Rollback if recent deployment**:
```bash
# Via Terraform
git revert HEAD
terraform apply -var-file=environments/dev.tfvars

# Or via AWS CLI
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition <previous-stable-version>
```

5. **Communicate**:
   - Notify stakeholders
   - Update status page

### Emergency: Security Incident

**Immediate Actions**:

1. **Isolate affected resources**:
```bash
# Remove ALB listener (stop incoming traffic)
aws elbv2 delete-listener \
  --listener-arn $(terraform output -raw http_listener_arn)

# Or scale to zero
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --desired-count 0
```

2. **Capture evidence**:
```bash
# Export logs
aws logs create-export-task \
  --log-group-name $(terraform output -raw cloudwatch_log_group_name) \
  --from $(date -d '24 hours ago' +%s)000 \
  --to $(date +%s)000 \
  --destination s3://incident-logs-bucket

# Snapshot task definition
aws ecs describe-task-definition \
  --task-definition $(terraform output -raw ecs_task_definition_family) \
  > task-definition-snapshot.json
```

3. **Investigate**:
   - Review CloudTrail logs
   - Check for unauthorized access
   - Review security group changes

4. **Remediate**:
   - Rotate credentials
   - Update security groups
   - Patch vulnerabilities
   - Deploy clean container image

### Emergency: Data Loss

**Note**: This infrastructure is stateless. Data should be in RDS/S3/DynamoDB.

If Terraform state is lost:
```bash
# Import existing resources
terraform import aws_s3_bucket.terraform_state aws-terraform-vinicius-study
terraform import aws_dynamodb_table.terraform_state_lock terraform-state-lock

# Manually reconcile state
terraform plan
```

## Maintenance

### Update Container Image

```bash
# 1. Build new version
docker build -t myapp:v2 .

# 2. Push to ECR
ECR_REPO=$(terraform output -raw ecr_repository_url)
docker tag myapp:v2 $ECR_REPO:v2
docker push $ECR_REPO:v2

# 3. Update configuration
# Edit environments/dev.tfvars
container_image = "<ecr-repo>:v2"

# 4. Deploy
terraform apply -var-file=environments/dev.tfvars

# 5. Monitor
aws ecs describe-services --cluster $CLUSTER --services $SERVICE
```

### Update Terraform

```bash
# 1. Update version in versions.tf
terraform {
  required_version = ">= 1.6.0"  # Update version
}

# 2. Update providers
terraform init -upgrade

# 3. Test
terraform plan -var-file=environments/dev.tfvars

# 4. Apply
terraform apply -var-file=environments/dev.tfvars
```

### Rotate Secrets

```bash
# 1. Update secret in Secrets Manager
aws secretsmanager update-secret \
  --secret-id my-app/db-password \
  --secret-string "new-password"

# 2. Force new deployment
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment

# Tasks will restart with new secret
```

## Common Tasks

### Scale Service Manually

```bash
# Scale up
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --desired-count 4

# Scale down
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --desired-count 1
```

### Execute Command in Running Task (ECS Exec)

```bash
# Prerequisites: enable_execute_command = true

# Get task ID
TASK_ID=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --query 'taskArns[0]' --output text)

# Execute command
aws ecs execute-command \
  --cluster $CLUSTER \
  --task $TASK_ID \
  --container app \
  --interactive \
  --command "/bin/sh"
```

### View Real-time Metrics

```bash
# CPU and Memory
watch -n 5 "aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].{Running:runningCount,CPU:\"CPUUtilization\",Memory:\"MemoryUtilization\"}'"
```

### Force New Deployment

```bash
# Forces ECS to pull latest image and restart tasks
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment
```

### Drain and Replace Tasks

```bash
# Gracefully replace all running tasks
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --deployment-configuration maximumPercent=200,minimumHealthyPercent=100
```

## On-Call Playbook

### Alert: High CPU

1. Check current CPU usage
2. Verify auto-scaling is working
3. If at max capacity, manually increase desired count
4. Investigate root cause in logs
5. Create ticket for performance optimization

### Alert: High Memory

1. Check for memory leaks in logs
2. Increase task memory temporarily
3. Force new deployment
4. Monitor for OOM kills
5. Create ticket for memory optimization

### Alert: Unhealthy Targets

1. Check task health in ECS
2. Review application logs
3. Verify health check endpoint
4. Test application manually
5. Rollback if recent deployment

### Alert: Deployment Failed

1. Check circuit breaker events
2. Review task stopped reasons
3. Verify container image is valid
4. Check IAM permissions
5. Rollback to previous version

## Contact Information

- **AWS Support**: +1-XXX-XXX-XXXX
- **On-call Engineer**: Slack #on-call
- **Team Lead**: email@example.com

## Useful Links

- [AWS Console](https://console.aws.amazon.com/)
- [CloudWatch Dashboard](https://console.aws.amazon.com/cloudwatch/)
- [ECS Cluster](https://console.aws.amazon.com/ecs/)
- [Terraform State](https://console.aws.amazon.com/s3/)
- [Documentation](../README.md)
