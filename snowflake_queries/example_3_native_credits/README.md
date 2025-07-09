# Native Credits-Based Cost Allocation

Allocate Snowflake warehouse costs by credits consumed using native metadata.

## Cost Allocation Method

- **Splits**: Warehouse costs across Database, Schema, User, Role, Query Tag
- **Usage Metric**: Snowflake credits consumed
- **Result**: Warehouse cost per database/user/tag based on credits used

## What Gets Allocated

Each query's credit consumption determines its share of warehouse costs:
- High-credit queries = Higher cost allocation
- Low-credit queries = Lower cost allocation
- Zero-credit queries = Excluded from allocation

## Setup

### 1. Create Snowflake View

```sql
-- Copy and run the full content from query_tags_by_credits.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_CREDITS_ALLOCATION AS
-- ... (see query_tags_by_credits.sql for complete SQL)
```

### 2. Configure Usage Tracking (Optional)

```sql
-- Line 12: Change analysis period
DATEADD('month', -3, CURRENT_TIMESTAMP()) -- 3 months instead of 6

-- Line 25: Minimum credits threshold
AND COALESCE(credits_used_cloud_services, 0) > 0.01 -- Exclude very small credit usage
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
python ../shared/handler.py query_tags_by_credits.sql
```

### 5. Schedule Hourly

```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_tags_by_credits.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by credits consumed
- Direct correlation between credits used and cost allocation
- More accurate cost attribution than time-based allocation
- Reflects actual Snowflake billing patterns in cost splits

## Key Metrics

- **Total credits processed**: Sum of credits across all queries
- **Total queries processed**: Number of queries included in allocation
- **Cost per credit**: Warehouse cost divided by total credits consumed
- **Top credit consumers**: Queries/users/databases with highest credit usage

## Advantages

- **Direct cost correlation**: Credits directly map to Snowflake billing
- **Resource intensity**: Reflects actual compute resource consumption
- **Billing accuracy**: Matches how Snowflake charges for usage
- **Performance insight**: High credits often indicate optimization opportunities

## Troubleshooting

- **No credit data**: Check if `credits_used_cloud_services` is populated (requires recent Snowflake version)
- **Missing allocations**: Verify CloudZero API key and telemetry stream setup
- **Low credit values**: Confirm queries are consuming measurable credits
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Credit thresholds**: Set minimum credit consumption for inclusion
- **Time periods**: Adjust analysis window and hourly buckets
- **Filtering**: Add warehouse-specific or query-type filters
- **Aggregation**: Modify grouping dimensions

---

*Most accurate cost correlation | Direct billing alignment | Performance insights*