# Custom JSON Data Volume Cost Allocation

Allocate Snowflake warehouse costs using custom metadata embedded in queries, based on data volume processed.

## Cost Allocation Method

- **Splits**: Warehouse costs across your custom business dimensions
- **Usage Metric**: Bytes scanned during query execution
- **Result**: Warehouse cost per custom dimension based on data volume processed

## What Gets Allocated

Each query's data volume consumption determines its share of warehouse costs, allocated by your custom metadata:
- Custom dimensions: customer_id, team, project, environment, etc.
- Business context: Cost centers, departments, applications
- Storage-intensive operations: Large data scans, ETL processes, analytics workloads

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
-- Copy and run the full content from query_bytes_custom.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME AS
-- ... (see query_bytes_custom.sql for complete SQL)
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
SELECT * FROM large_table WHERE region = 'US';

-- After  
SELECT /*QUERYDATA>{"customer_id": "customer-123", "team": "analytics"}<QUERYDATA*/
    * FROM large_table WHERE region = 'US';
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
python ../shared/handler.py query_bytes_custom.sql
```

### 6. Schedule Hourly

```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_bytes_custom.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by your custom dimensions
- Cost allocation by customer_id, team, project, environment, etc.
- Fair allocation based on actual data volume consumed
- Clear visibility into which dimensions drive storage-intensive operations

## Key Metrics

- **Total queries processed**: Number of queries with valid metadata and data volume
- **Total data volume allocated**: Sum of bytes scanned across tagged queries
- **Data volume per dimension**: Bytes scanned by customer/team/project
- **Top data consumers**: Custom dimensions with highest data volume consumption

## Advantages

- **Fair allocation**: Queries scanning more data pay proportionally more
- **Storage visibility**: Clear view of which dimensions drive data-intensive operations
- **Business alignment**: Cost allocation matches organizational structure
- **ETL optimization**: Identify teams/projects with inefficient data processing

## When to Use Data Volume Allocation

Data volume allocation is ideal when:
- You have storage-intensive workloads with varying data scan patterns
- You want to allocate costs based on actual data consumption
- You need to identify and optimize data-heavy operations
- You want to charge customers based on their data usage patterns

## Data Volume Considerations

- **Minimum threshold**: 1MB minimum scan to exclude trivial queries
- **Cache hits**: Optionally exclude high cache hit queries (uncomment line 79)
- **Scale factor**: Values are in MB for manageable numbers
- **Allocation timing**: Full data volume allocated to query start hour

## Metadata Examples

Common custom metadata patterns:

```sql
-- Customer-based data allocation
/*QUERYDATA>{"customer_id": "cust-123", "data_category": "analytics"}<QUERYDATA*/

-- Team-based allocation
/*QUERYDATA>{"team": "data-engineering", "project": "etl-pipeline"}<QUERYDATA*/

-- Environment-based allocation
/*QUERYDATA>{"environment": "prod", "service": "reporting-api"}<QUERYDATA*/

-- Multi-dimensional allocation
/*QUERYDATA>{"customer_id": "cust-456", "team": "analytics", "project": "ml-model", "environment": "staging"}<QUERYDATA*/
```

## Troubleshooting

- **No data volume**: Check that queries are actually scanning data (not metadata operations)
- **Parsing errors**: Verify JSON syntax in metadata comments
- **Missing allocations**: Confirm queries include properly formatted QUERYDATA comments
- **Low volume values**: Ensure queries meet minimum 1MB scan threshold
- **Cache considerations**: Check if high cache hit queries should be excluded
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Metadata fields**: Add/remove fields based on your business dimensions
- **JSON structure**: Modify the metadata format for your needs
- **Volume thresholds**: Adjust minimum data scan requirements
- **Cache filtering**: Enable/disable cache hit exclusions
- **Filtering**: Add conditions to exclude certain query types
- **Aggregation**: Modify grouping dimensions

## Performance Optimization

For large-scale data volume tracking:
- Consider partitioning by date ranges
- Index on commonly queried metadata fields
- Monitor query performance and adjust thresholds
- Use warehouse auto-scaling for variable workloads

---

*Custom business dimensions | Data volume allocation | Storage-intensive workload optimization*