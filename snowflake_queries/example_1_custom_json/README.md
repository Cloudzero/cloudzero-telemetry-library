# Custom JSON Metadata Cost Allocation

Allocate Snowflake warehouse costs using custom metadata embedded in queries.

## Cost Allocation Method

- **Splits**: Warehouse costs across your custom business dimensions
- **Usage Metric**: Query execution time in milliseconds
- **Result**: Warehouse cost per custom dimension based on time consumed

## What Gets Allocated

Each query's execution time determines its share of warehouse costs, allocated by your custom metadata:
- Custom dimensions: customer_id, team, project, environment, etc.
- Business context: Cost centers, departments, applications
- Flexible tagging: Any JSON metadata you embed in queries

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
-- Copy and run the full content from query_execution_time.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME AS
-- ... (see query_execution_time.sql for complete SQL)
```

### 2. Configure Custom Fields (Required)

```sql
-- Line 28: Customize for your metadata fields
COALESCE(query_data:customer_id::string, 'unknown') AS customer_id,
COALESCE(query_data:team::string, 'unknown') AS team,
COALESCE(query_data:project::string, 'unknown') AS project,
COALESCE(query_data:environment::string, 'unknown') AS environment,

-- Line 33: Update element_name construction
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
python ../shared/handler.py query_execution_time.sql
```

### 6. Schedule Hourly

```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_execution_time.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by your custom dimensions
- Cost allocation by customer_id, team, project, environment, etc.
- Business-relevant cost attribution beyond database/schema/user
- Flexible metadata for any organizational structure

## Key Metrics

- **Total queries processed**: Number of queries with valid metadata
- **Total time allocated**: Sum of execution time across tagged queries
- **Cost per dimension**: Warehouse cost by customer/team/project
- **Top cost drivers**: Custom dimensions with highest time consumption

## Advantages

- **Business alignment**: Cost allocation matches organizational structure
- **Flexible dimensions**: Any metadata fields relevant to your business
- **Custom reporting**: Dashboard views tailored to your needs
- **Detailed attribution**: Granular cost allocation beyond standard fields

## Metadata Examples

Common custom metadata patterns:

```sql
-- Customer-based allocation
/*QUERYDATA>{"customer_id": "cust-123", "customer_tier": "enterprise"}<QUERYDATA*/

-- Team-based allocation
/*QUERYDATA>{"team": "data-engineering", "project": "etl-pipeline"}<QUERYDATA*/

-- Environment-based allocation
/*QUERYDATA>{"environment": "prod", "service": "analytics-api"}<QUERYDATA*/

-- Multi-dimensional allocation
/*QUERYDATA>{"customer_id": "cust-456", "team": "analytics", "project": "ml-model", "environment": "staging"}<QUERYDATA*/
```

## Troubleshooting

- **No metadata**: Check that queries include properly formatted QUERYDATA comments
- **Parsing errors**: Verify JSON syntax in metadata comments
- **Missing allocations**: Confirm queries are running with metadata tags
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Metadata fields**: Add/remove fields based on your business dimensions
- **JSON structure**: Modify the metadata format for your needs
- **Filtering**: Add conditions to exclude certain query types
- **Aggregation**: Modify grouping dimensions

---

*Custom business dimensions | Flexible metadata | Business-aligned allocation*