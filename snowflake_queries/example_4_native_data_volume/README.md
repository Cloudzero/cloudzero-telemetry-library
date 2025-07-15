# Native Data Volume-Based Cost Allocation

Allocate Snowflake warehouse costs by data volume processed using native metadata.

## Cost Allocation Method

- **Splits**: Warehouse costs across Database, Schema, User, Role, Query Tag
- **Usage Metric**: Bytes scanned during query execution
- **Result**: Warehouse cost per database/user/tag based on data volume processed

## What Gets Allocated

Each query's data scan volume determines its share of warehouse costs:
- High-volume scans = Higher cost allocation
- Low-volume scans = Lower cost allocation
- Cache hits = Lower allocation (reduced scanning)

## Setup

### 1. Create Snowflake View

```sql
-- Copy and run the full content from query_tags_by_bytes.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_DATA_VOLUME_ALLOCATION AS
-- ... (see query_tags_by_bytes.sql for complete SQL)
```

### 2. Configure Usage Tracking (Optional)

```sql
-- Line 12: Change analysis period
DATEADD('month', -3, CURRENT_TIMESTAMP()) -- 3 months instead of 6

-- Line 25: Minimum bytes threshold
AND COALESCE(bytes_scanned, 0) > 1000000 -- Exclude scans under 1MB
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
python ../shared/handler.py query_tags_by_bytes.sql
```

### 5. Schedule Hourly

```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_tags_by_bytes.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by data volume processed
- Cost allocation reflects data access patterns and storage utilization
- Rewards efficient queries that scan less data
- Identifies data-heavy operations driving costs

## Key Metrics

- **Total bytes processed**: Sum of bytes scanned across all queries
- **Total queries processed**: Number of queries included in allocation
- **Cost per byte**: Warehouse cost divided by total bytes scanned
- **Top data consumers**: Queries/users/databases with highest data volume

## Advantages

- **Storage correlation**: Reflects data access patterns and storage costs
- **Efficiency incentive**: Rewards optimized queries with lower allocation
- **Cache awareness**: Differentiates between cached and storage access
- **Optimization insight**: Identifies opportunities for data pruning

## Use Cases

- **Data-intensive workloads**: ETL processes, analytics, large table scans
- **Storage optimization**: Identifying tables/queries with high scan volumes
- **Performance tuning**: Correlating data volume with query performance
- **Cost optimization**: Finding opportunities to reduce data scanning

## Troubleshooting

- **No bytes data**: Check if `bytes_scanned` is populated in QUERY_HISTORY
- **Missing allocations**: Verify CloudZero API key and telemetry stream setup
- **Zero byte scans**: Confirm queries are actually scanning data (not cached)
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Volume thresholds**: Set minimum scan volume for inclusion
- **Time periods**: Adjust analysis window and hourly buckets
- **Filtering**: Add warehouse-specific or query-type filters
- **Aggregation**: Modify grouping dimensions

---

*Storage-focused allocation | Efficiency incentive | Data optimization insights*