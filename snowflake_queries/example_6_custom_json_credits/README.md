# Custom JSON Credits-Based Cost Allocation

Allocate Snowflake warehouse costs using custom metadata embedded in queries, based on credits consumed.

## Cost Allocation Method

- **Splits**: Warehouse costs across your custom business dimensions
- **Usage Metric**: Credits consumed during query execution
- **Result**: Warehouse cost per custom dimension based on credits consumed

## What Gets Allocated

Each query's credit consumption determines its share of warehouse costs, allocated by your custom metadata:
- Custom dimensions: customer_id, team, project, environment, etc.
- Business context: Cost centers, departments, applications
- Direct cost correlation: Credits directly correlate with Snowflake billing

## Query Metadata Format

Embed JSON metadata in your queries using this format:

```sql
SELECT /*QUERYDATA>{"customer_id": "abc-123", "team": "analytics", "project": "revenue-dashboard"}<QUERYDATA*/
    customer_name,
    total_revenue
FROM customers
WHERE created_date >= '2024-01-01';
```

## Setup

### 1. Create Snowflake View

```sql
-- Copy and run the full content from query_credits_custom.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME AS
-- ... (see query_credits_custom.sql for complete SQL)
```

### 2. Configure Custom Fields (Required)

```sql
-- Line 43: Customize for your metadata fields
COALESCE(query_data:customer_id::string, 'unknown') AS customer_id,
COALESCE(query_data:team::string, 'unknown') AS team,
COALESCE(query_data:project::string, 'unknown') AS project,
COALESCE(query_data:environment::string, 'unknown') AS environment,

-- Line 50: Update element_name construction
ARRAY_TO_STRING(ARRAY_CONSTRUCT(
    COALESCE(query_data:customer_id::string, 'unknown'),
    COALESCE(query_data:team::string, 'unknown'),
    COALESCE(query_data:project::string, 'unknown'),
    COALESCE(query_data:environment::string, 'unknown')
), '||') AS element_name,
```

### 3. Add Metadata to Queries

Update your existing queries to include metadata:

```sql
-- Before
SELECT * FROM sales_data WHERE region = 'US';

-- After  
SELECT /*QUERYDATA>{"customer_id": "customer-123", "team": "sales"}<QUERYDATA*/
    * FROM sales_data WHERE region = 'US';
```

### 4. Set Environment Variables

```bash
export CLOUDZERO_API_KEY="your-api-key"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ACCOUNT="your-account"
export SECRETS_PROVIDER="env"
```

### 5. Run Collection Script

```bash
pip install -r ../shared/requirements.txt
python ../shared/handler.py query_credits_custom.sql
```

### 6. Deploy to Production

#### Cloud Deployment (Recommended)

**AWS Lambda**
```bash
export SECRETS_PROVIDER="aws"
export TELEMETRY_SECRETS_ID="cloudzero-api-key"
export SNOWFLAKE_SECRETS_ID="snowflake-credentials"
# Deploy as Lambda with EventBridge hourly trigger
```

**Azure Functions**
```bash
export SECRETS_PROVIDER="azure"
export AZURE_VAULT_URL="https://your-vault.vault.azure.net/"
# Deploy as Function App with Timer trigger
```

**Google Cloud Functions**
```bash
export SECRETS_PROVIDER="gcp"
export GCP_PROJECT_ID="your-project-id"
# Deploy as Cloud Function with Cloud Scheduler
```

**Kubernetes**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: snowflake-telemetry-credits-custom
spec:
  schedule: "30 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: snowflake-telemetry
            image: your-registry/snowflake-telemetry:latest
            command: ["python", "shared/handler.py", "example_6_custom_json_credits/query_credits_custom.sql"]
```

See [CLOUD_DEPLOYMENT.md](../CLOUD_DEPLOYMENT.md) for complete setup instructions.

#### Local Scheduling (Development/Testing)
```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_credits_custom.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by your custom dimensions
- Cost allocation by customer_id, team, project, environment, etc.
- Direct correlation with Snowflake billing through credits consumed
- Business-relevant cost attribution with accurate billing alignment

## Key Metrics

- **Total queries processed**: Number of queries with valid metadata and credits
- **Total credits allocated**: Sum of credits consumed across tagged queries
- **Cost per dimension**: Warehouse cost by customer/team/project (directly correlated)
- **Top cost drivers**: Custom dimensions with highest credit consumption

## Advantages

- **Direct cost correlation**: Credits directly correspond to Snowflake billing
- **Business alignment**: Cost allocation matches organizational structure
- **Flexible dimensions**: Any metadata fields relevant to your business
- **Accurate attribution**: Precise cost allocation based on actual resource consumption

## When to Use Credits-Based Allocation

Credits-based allocation is ideal when:
- You want direct correlation with Snowflake billing
- Queries have varying complexity and resource consumption
- You need to allocate costs based on actual compute consumption
- You want to charge back customers based on their actual usage

## Metadata Examples

Common custom metadata patterns:

```sql
-- Customer-based billing
/*QUERYDATA>{"customer_id": "cust-123", "customer_tier": "enterprise"}<QUERYDATA*/

-- Team-based allocation
/*QUERYDATA>{"team": "data-engineering", "project": "etl-pipeline"}<QUERYDATA*/

-- Environment-based allocation
/*QUERYDATA>{"environment": "prod", "service": "analytics-api"}<QUERYDATA*/

-- Multi-dimensional allocation
/*QUERYDATA>{"customer_id": "cust-456", "team": "analytics", "project": "ml-model", "environment": "staging"}<QUERYDATA*/
```

## Troubleshooting

- **No credits data**: Check that queries are actually consuming credits (not cache hits)
- **Parsing errors**: Verify JSON syntax in metadata comments
- **Missing allocations**: Confirm queries include properly formatted QUERYDATA comments
- **Low credit values**: Ensure minimum threshold (0.001 credits) is met
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Metadata fields**: Add/remove fields based on your business dimensions
- **JSON structure**: Modify the metadata format for your needs
- **Credit thresholds**: Adjust minimum credit consumption requirements
- **Filtering**: Add conditions to exclude certain query types
- **Aggregation**: Modify grouping dimensions

---

*Custom business dimensions | Credits-based allocation | Direct billing correlation*