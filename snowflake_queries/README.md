# Snowflake Usage-Based Cost Allocation Examples

Allocate shared Snowflake warehouse costs using query-level usage metrics and CloudZero's telemetry API.

## What This Does

Splits Snowflake warehouse costs based on actual usage patterns:
- **Warehouse cost per database** using query execution time
- **Warehouse cost per user** using credits consumed  
- **Warehouse cost per application** using custom metadata
- **Warehouse cost per data processed** using bytes scanned

## Choose Your Approach

### Usage Metrics (How costs are split)
| Usage Metric          | Description                | Best For                                     |
| --------------------- | -------------------------- | -------------------------------------------- |
| **Time-Based**        | Query execution time       | General workloads, intuitive understanding   |
| **Credits-Based**     | Snowflake credits consumed | Direct cost correlation, billing accuracy    |
| **Data Volume-Based** | Bytes scanned              | Storage-intensive workloads, data processing |
| **Composite**         | Weighted combination       | Complex environments, balanced allocation    |

### Metadata Options (What dimensions costs are split across)
| Metadata Method      | Dimensions                              | Best For                       |
| -------------------- | --------------------------------------- | ------------------------------ |
| **Native Snowflake** | Database, Schema, User, Role, Query Tag | Quick setup, existing metadata |
| **Custom JSON**      | Your embedded metadata                  | Custom business dimensions     |

## Examples

### Native Snowflake Metadata Examples
| Example                                             | Usage Metric         | Allocation Method                 |
| --------------------------------------------------- | -------------------- | --------------------------------- |
| [Native Time](example_2_native_time/)               | Query execution time | Warehouse cost per millisecond    |
| [Native Credits](example_3_native_credits/)         | Credits consumed     | Warehouse cost per credit         |
| [Native Data Volume](example_4_native_data_volume/) | Bytes scanned        | Warehouse cost per byte           |
| [Native Composite](example_5_native_composite/)     | Weighted combination | Warehouse cost per composite score |

### Custom JSON Metadata Examples
| Example                                                         | Usage Metric         | Allocation Method                                  |
| --------------------------------------------------------------- | -------------------- | -------------------------------------------------- |
| [Custom JSON Time](example_1_custom_json/)                     | Query execution time | Warehouse cost per millisecond (custom dimensions) |
| [Custom JSON Credits](example_6_custom_json_credits/)          | Credits consumed     | Warehouse cost per credit (custom dimensions)      |
| [Custom JSON Data Volume](example_7_custom_json_data_volume/)  | Bytes scanned        | Warehouse cost per byte (custom dimensions)        |
| [Custom JSON Composite](example_8_custom_json_composite/)      | Weighted combination | Warehouse cost per composite score (custom dimensions) |

## Quick Start

1. **5-minute setup**: See [QUICK_START.md](QUICK_START.md)
2. **Choose example**: Go to specific example directory
3. **Deploy**: Run SQL + Python script
4. **Verify**: Check CloudZero dashboard for allocated warehouse costs

## How It Works

1. **Create Snowflake view** that extracts usage metrics and metadata
2. **Run Python script** that queries the view and sends data to CloudZero
3. **Schedule hourly** to continuously allocate costs
4. **View results** in CloudZero dashboard as allocated warehouse costs

## Deployment Options

### Local Development & Testing
```bash
# Set environment variables
export CLOUDZERO_API_KEY="your-api-key"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ACCOUNT="your-account"
export SECRETS_PROVIDER="env"

# Run directly
python shared/handler.py example_2_native_time/query_tags_by_time.sql
```

### Cloud Provider Deployment

The handler is designed to run in any cloud environment:

#### AWS
- **Compute**: Lambda functions, ECS tasks, or EC2 instances
- **Secrets**: AWS Secrets Manager integration (`SECRETS_PROVIDER="aws"`)
- **Scheduling**: EventBridge rules or CloudWatch Events
- **Monitoring**: CloudWatch logs and metrics

#### Azure
- **Compute**: Azure Functions, Container Instances, or Virtual Machines
- **Secrets**: Azure Key Vault integration (`SECRETS_PROVIDER="azure"`)
- **Scheduling**: Timer triggers or Azure Logic Apps
- **Monitoring**: Application Insights and Azure Monitor

#### Google Cloud
- **Compute**: Cloud Functions, Cloud Run, or Compute Engine
- **Secrets**: Secret Manager integration (`SECRETS_PROVIDER="gcp"`)
- **Scheduling**: Cloud Scheduler or Pub/Sub triggers
- **Monitoring**: Cloud Logging and Cloud Monitoring

#### Kubernetes (Any Cloud)
- **Deployment**: CronJob resources for scheduled execution
- **Secrets**: Kubernetes secrets or external secrets operators
- **Scheduling**: Native cron scheduling with pod restarts
- **Monitoring**: Prometheus metrics and centralized logging

### Production Considerations

- **Secrets Management**: Integrates with cloud-native secrets management services
- **Monitoring**: Supports standard cloud monitoring and alerting patterns
- **Scaling**: Designed for single-threaded execution per warehouse
- **Error Handling**: Built-in retry logic and comprehensive error reporting
- **Cost**: Minimal compute cost - typically runs for seconds per hour
- **Scheduling**: Requires hourly execution for continuous cost allocation

## Need Help?

Contact your CloudZero representative for assistance with setup or configuration.


