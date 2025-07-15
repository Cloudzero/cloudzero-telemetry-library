# Custom JSON Composite Cost Allocation

Allocate Snowflake warehouse costs using custom metadata embedded in queries, based on a weighted combination of multiple usage metrics.

## Cost Allocation Method

- **Splits**: Warehouse costs across your custom business dimensions
- **Usage Metric**: Composite score combining execution time, credits, and data volume
- **Result**: Warehouse cost per custom dimension based on comprehensive resource usage

## What Gets Allocated

Each query's composite score determines its share of warehouse costs, allocated by your custom metadata:
- Custom dimensions: customer_id, team, project, environment, etc.
- Business context: Cost centers, departments, applications
- Comprehensive usage: Balanced allocation across compute, credits, and data volume

## Composite Scoring

The composite score uses configurable weights (must sum to 1.0):

- **Time Weight (40%)**: Execution time in milliseconds
- **Credits Weight (40%)**: Credits consumed (scaled by 1000)
- **Data Volume Weight (20%)**: Data scanned in MB

```sql
-- Configuration in lines 20-26
0.4 AS time_weight,        -- 40% weight for execution time
0.4 AS credits_weight,     -- 40% weight for credits consumed
0.2 AS data_volume_weight  -- 20% weight for data volume
```

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
-- Copy and run the full content from query_composite_custom.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME AS
-- ... (see query_composite_custom.sql for complete SQL)
```

### 2. Configure Custom Fields (Required)

```sql
-- Line 46: Customize for your metadata fields
COALESCE(query_data:customer_id::string, 'unknown') AS customer_id,
COALESCE(query_data:team::string, 'unknown') AS team,
COALESCE(query_data:project::string, 'unknown') AS project,
COALESCE(query_data:environment::string, 'unknown') AS environment,

-- Line 53: Update element_name construction
ARRAY_TO_STRING(ARRAY_CONSTRUCT(
    COALESCE(query_data:customer_id::string, 'unknown'),
    COALESCE(query_data:team::string, 'unknown'),
    COALESCE(query_data:project::string, 'unknown'),
    COALESCE(query_data:environment::string, 'unknown')
), '||') AS element_name,
```

### 3. Adjust Composite Weights (Optional)

Modify weights based on your organizational priorities:

```sql
-- Example: Emphasize credits over time
0.2 AS time_weight,        -- 20% weight for execution time
0.6 AS credits_weight,     -- 60% weight for credits consumed
0.2 AS data_volume_weight  -- 20% weight for data volume

-- Example: Emphasize data volume
0.3 AS time_weight,        -- 30% weight for execution time
0.3 AS credits_weight,     -- 30% weight for credits consumed
0.4 AS data_volume_weight  -- 40% weight for data volume
```

### 4. Add Metadata to Queries

Update your existing queries to include metadata:

```sql
-- Before
SELECT * FROM large_table WHERE region = 'US';

-- After  
SELECT /*QUERYDATA>{"customer_id": "customer-123", "team": "analytics"}<QUERYDATA*/
    * FROM large_table WHERE region = 'US';
```

### 5. Set Environment Variables

```bash
export CLOUDZERO_API_KEY="your-api-key"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ACCOUNT="your-account"
export SECRETS_PROVIDER="env"
```

### 6. Run Collection Script

```bash
pip install -r ../shared/requirements.txt
python ../shared/handler.py query_composite_custom.sql
```

### 7. Schedule Hourly

```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_composite_custom.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by your custom dimensions
- Cost allocation by customer_id, team, project, environment, etc.
- Balanced allocation considering compute time, billing credits, and data volume
- Comprehensive view of resource consumption across multiple dimensions

## Key Metrics

- **Total queries processed**: Number of queries with valid metadata and composite scores
- **Total composite score**: Sum of weighted scores across tagged queries
- **Score per dimension**: Composite score by customer/team/project
- **Top resource consumers**: Custom dimensions with highest composite scores

## Advantages

- **Comprehensive allocation**: Considers multiple aspects of resource usage
- **Configurable weights**: Adjust allocation priorities based on business needs
- **Business alignment**: Cost allocation matches organizational structure
- **Balanced view**: Avoids bias toward any single usage metric

## When to Use Composite Allocation

Composite allocation is ideal when:
- You want balanced allocation across multiple resource types
- Different workloads have varying patterns (CPU vs. data vs. credits)
- You need fair allocation that considers all aspects of resource consumption
- You want to avoid bias from focusing on a single metric

## Weight Configuration Guidelines

**Equal weights (33% each)**: Balanced allocation across all metrics
**Credits-heavy (e.g., 60% credits)**: Emphasize direct billing correlation
**Time-heavy (e.g., 60% time)**: Emphasize compute-intensive operations
**Data-heavy (e.g., 60% data volume)**: Emphasize storage-intensive operations

## Metadata Examples

Common custom metadata patterns:

```sql
-- Customer-based comprehensive allocation
/*QUERYDATA>{"customer_id": "cust-123", "workload_type": "analytics"}<QUERYDATA*/

-- Team-based allocation
/*QUERYDATA>{"team": "data-engineering", "project": "etl-pipeline"}<QUERYDATA*/

-- Environment-based allocation
/*QUERYDATA>{"environment": "prod", "service": "reporting-api"}<QUERYDATA*/

-- Multi-dimensional allocation
/*QUERYDATA>{"customer_id": "cust-456", "team": "analytics", "project": "ml-model", "environment": "staging"}<QUERYDATA*/
```

## Troubleshooting

- **Low composite scores**: Check that queries meet minimum thresholds for at least one metric
- **Parsing errors**: Verify JSON syntax in metadata comments
- **Missing allocations**: Confirm queries include properly formatted QUERYDATA comments
- **Weight validation**: Ensure weights sum to 1.0 in configuration
- **Metric balance**: Review individual metric contributions in composite scores
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Metadata fields**: Add/remove fields based on your business dimensions
- **JSON structure**: Modify the metadata format for your needs
- **Composite weights**: Adjust weights based on organizational priorities
- **Metric thresholds**: Modify minimum values for inclusion
- **Filtering**: Add conditions to exclude certain query types
- **Aggregation**: Modify grouping dimensions

## Performance Considerations

For optimal performance:
- Monitor composite score distributions
- Adjust weights based on actual usage patterns
- Consider query complexity when interpreting scores
- Use appropriate warehouse sizing for varied workloads

## Advanced Configuration

For complex scenarios:
- Add custom scaling factors for specific metrics
- Implement time-based weight adjustments
- Create workload-specific composite formulas
- Add query classification logic

---

*Custom business dimensions | Composite allocation | Comprehensive resource usage*