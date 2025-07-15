# Native Composite Cost Allocation

Allocate Snowflake warehouse costs using a weighted combination of usage metrics.

## Cost Allocation Method

- **Splits**: Warehouse costs across Database, Schema, User, Role, Query Tag
- **Usage Metric**: Weighted combination of time, credits, and data volume
- **Result**: Warehouse cost per database/user/tag based on composite usage score

## What Gets Allocated

Each query's composite score determines its share of warehouse costs:
- High composite scores = Higher cost allocation
- Low composite scores = Lower cost allocation
- Balanced across multiple resource dimensions

## Composite Score Formula

```sql
-- Default weighting (customizable)
composite_score = (execution_time * 0.4) + 
                  (credits_used_cloud_services * 1000 * 0.4) + 
                  (bytes_scanned / 1000000 * 0.2)
```

## Setup

### 1. Create Snowflake View

```sql
-- Copy and run the full content from query_tags_composite.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_COMPOSITE_ALLOCATION AS
-- ... (see query_tags_composite.sql for complete SQL)
```

### 2. Configure Weights (Optional)

```sql
-- Line 30: Adjust composite score weighting
(execution_time * 0.4) +                    -- Time weight: 40%
(credits_used_cloud_services * 1000 * 0.4) + -- Credits weight: 40%
(bytes_scanned / 1000000 * 0.2)             -- Data volume weight: 20%
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
python ../shared/handler.py query_tags_composite.sql
```

### 5. Schedule Hourly

```bash
# Cron example
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/query_tags_composite.sql
```

## Expected Results

- CloudZero dashboard shows warehouse costs allocated by composite usage score
- Balanced cost allocation across multiple resource dimensions
- More comprehensive cost attribution than single-metric approaches
- Reflects overall resource consumption patterns

## Key Metrics

- **Total composite score**: Sum of weighted scores across all queries
- **Total queries processed**: Number of queries included in allocation
- **Cost per composite unit**: Warehouse cost divided by total composite score
- **Top composite consumers**: Queries/users/databases with highest composite scores

## Advantages

- **Comprehensive**: Considers multiple resource dimensions simultaneously
- **Balanced**: Prevents single-metric bias in cost allocation
- **Customizable**: Weights can be adjusted for organizational priorities
- **Holistic**: Reflects true resource consumption patterns

## Use Cases

- **Complex workloads**: Mixed analytical and operational queries
- **Balanced allocation**: When no single metric fully represents usage
- **Organizational tuning**: Adjust weights to match business priorities
- **Comprehensive costing**: Full resource consumption visibility

## Weight Tuning Guidelines

- **Time-heavy workloads**: Increase execution_time weight
- **Compute-intensive**: Increase credits_used weight
- **Data-intensive**: Increase bytes_scanned weight
- **Balanced approach**: Equal weights across all metrics

## Troubleshooting

- **Skewed results**: Check if weights need adjustment for your workload
- **Missing data**: Verify all metrics are populated in QUERY_HISTORY
- **Low scores**: Confirm queries have meaningful values for all metrics
- **Questions**: Contact your CloudZero representative

## Customization

This example can be customized for your specific needs:
- **Metric weights**: Adjust the balance between time, credits, and data volume
- **Additional metrics**: Include other QUERY_HISTORY fields in composite score
- **Scaling factors**: Modify scaling to normalize different metric ranges
- **Filtering**: Add conditions to exclude certain query types

---

*Comprehensive allocation | Balanced approach | Customizable weighting*