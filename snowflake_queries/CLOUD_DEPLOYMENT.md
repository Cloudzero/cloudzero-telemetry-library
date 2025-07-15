# Cloud Deployment Overview

The telemetry handler is designed for cloud-native deployment with support for all major cloud providers.

## Architecture

- **Single command execution**: `python shared/handler.py <sql_file>`
- **Multi-cloud secrets integration**: AWS, Azure, GCP, Kubernetes
- **Stateless operation**: No persistent storage required
- **Lightweight runtime**: Seconds per execution
- **Hourly scheduling**: Compatible with any scheduler

## Deployment Options

The handler is a standard Python application that can run on any compute platform. It includes built-in integrations for:

### AWS
- **Secrets**: AWS Secrets Manager integration (`SECRETS_PROVIDER="aws"`)
- **Compute**: Can run on Lambda, ECS, EC2, Batch (standard Python execution)
- **Scheduling**: Use EventBridge, CloudWatch Events, or cron

### Azure
- **Secrets**: Azure Key Vault integration (`SECRETS_PROVIDER="azure"`)
- **Compute**: Can run on Functions, Container Instances, VMs (standard Python execution)
- **Scheduling**: Use Timer triggers, Logic Apps, or cron

### Google Cloud
- **Secrets**: Secret Manager integration (`SECRETS_PROVIDER="gcp"`)
- **Compute**: Can run on Cloud Functions, Cloud Run, Compute Engine (standard Python execution)
- **Scheduling**: Use Cloud Scheduler, Pub/Sub, or cron

### Kubernetes
- **Secrets**: Environment variables from Kubernetes secrets or external secrets operators
- **Compute**: Can run as CronJob, Job, or Pod (standard Python execution)
- **Scheduling**: Use CronJob resources or external schedulers

## Production Considerations

### Security
- Use cloud-native secrets management
- Enable VPC/VNet integration for secure database access
- Implement least privilege access controls
- Enable audit logging

### Monitoring
- Configure failure alerts using your cloud provider's monitoring
- Monitor execution through standard application logging
- Track data quality and volume through log analysis
- Set up performance monitoring using your existing tools

### Scaling
- Deploy separate instances per warehouse
- Right-size compute resources
- Optimize batch sizes for performance
- Use appropriate scheduling intervals

### High Availability
- Deploy across multiple availability zones
- Implement retry logic and circuit breakers
- Configure backup and disaster recovery
- Monitor system health

---

*Enterprise-ready | Multi-cloud | Scalable*