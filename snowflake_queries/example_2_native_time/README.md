# Native Time-Based Cost Allocation

Allocate Snowflake warehouse costs by query execution time using native metadata.

## Cost Allocation Method

- **Splits**: Warehouse costs across Database, Schema, User, Role, Query Tag
- **Usage Metric**: Query execution time in milliseconds
- **Result**: Warehouse cost per database/user/tag based on time consumed

## What Gets Allocated

Each query's execution time determines its share of warehouse costs:
- Long-running queries = Higher cost allocation
- Short queries = Lower cost allocation
- Cached queries = Excluded (no warehouse cost)

## Setup

### 1. Create Snowflake View

```sql
-- Copy and run the full content from query_tags_by_time.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME AS
-- ... (see query_tags_by_time.sql for complete SQL)
```

### 2. Configure Usage Tracking (Optional)

```sql
-- Line 12: Change analysis period
DATEADD('month', -3, CURRENT_TIMESTAMP()) -- 3 months instead of 6

-- Line 16: Customize metadata fields
COALESCE(DATABASE_NAME, 'unknown') AS database_name,
COALESCE(SCHEMA_NAME, 'unknown') AS schema_name,
COALESCE(USER_NAME, 'unknown') AS user_name,
COALESCE(QUERY_TAG, 'unknown') AS query_tag,
COALESCE(ROLE_NAME, 'unknown') AS role_name
```

### 3. Set Environment Variables

```bash
export CLOUDZERO_API_KEY="your-api-key"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ACCOUNT="your-account"
export SECRETS_PROVIDER="env"
```

### 4. Run Collection Script

```bash
pip install -r ../shared/requirements.txt
python ../shared/handler.py query_tags_by_time.sql
```

### 5. Deploy to Production

#### Cloud Deployment (Recommended)

The handler supports deployment across all major cloud providers:

**AWS**: Lambda functions, ECS tasks, or EC2 instances with AWS Secrets Manager
**Azure**: Functions, Container Instances, or VMs with Azure Key Vault  
**Google Cloud**: Cloud Functions, Cloud Run, or Compute Engine with Secret Manager
**Kubernetes**: CronJob resources with native secrets or external secrets operators

All cloud deployments use the same command: `python shared/handler.py query_tags_by_time.sql`

Configure your cloud provider with:
- `SECRETS_PROVIDER="aws"` (or "azure", "gcp")
- Hourly scheduling (recommended: 30 minutes past each hour)
- Cloud-native secrets management for credentials

See [CLOUD_DEPLOYMENT.md](../CLOUD_DEPLOYMENT.md) for architecture and deployment considerations.

#### Local Scheduling (Development/Testing)
```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_tags_by_time.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by your metadata
- Hourly cost breakdowns by database, user, role, or query tag
- Usage-based cost attribution for shared warehouse resources

## Key Metrics

- **Total queries processed**: Number of queries included in allocation
- **Total time allocated**: Sum of execution time across all queries
- **Cost per millisecond**: Warehouse cost divided by total execution time
- **Top cost drivers**: Queries/users/databases with highest time consumption

## Troubleshooting

- **No cost data**: Check `ACCOUNT_USAGE` permissions for your Snowflake user
- **Missing allocations**: Verify CloudZero API key and telemetry stream setup
- **Low query count**: Confirm queries are running on the target warehouses
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Metadata fields**: Add/remove fields in the element_name construction
- **Time periods**: Adjust analysis window and hourly buckets
- **Filtering**: Add warehouse-specific or query-type filters
- **Aggregation**: Modify grouping dimensions

---

*Most common usage metric | Easy to understand | Works with existing metadata*