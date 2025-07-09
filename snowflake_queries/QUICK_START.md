# 5-Minute Setup Guide

Get Snowflake warehouse cost allocation running in 5 minutes.

## Prerequisites

- Snowflake account with `ACCOUNT_USAGE` access
- CloudZero API key
- Python 3.8+

## Step 1: Choose Your Example

| Example | Usage Metric | Best For |
|---------|-------------|----------|
| [Native Time](example_2_native_time/) | Query execution time | Most users (recommended) |
| [Native Credits](example_3_native_credits/) | Credits consumed | Direct cost tracking |
| [Native Data Volume](example_4_native_data_volume/) | Bytes scanned | Data-intensive workloads |
| [Custom JSON](example_1_custom_json/) | Query execution time | Custom metadata |

## Step 2: Set Environment Variables

```bash
export CLOUDZERO_API_KEY="your-api-key"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ACCOUNT="your-account"
export SECRETS_PROVIDER="env"
```

## Step 3: Install Dependencies

```bash
pip install -r shared/requirements.txt
```

## Step 4: Create Snowflake View

Copy the SQL from your chosen example and run in Snowflake:

```sql
-- Example: From example_2_native_time/query_tags_by_time.sql
CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME AS
-- ... (copy full SQL content)
```

## Step 5: Run Collection Script

```bash
# Replace with your chosen example
python shared/handler.py example_2_native_time/query_tags_by_time.sql
```

## Step 6: Schedule Hourly

Set up hourly execution using your preferred scheduler:

```bash
# Cron example (runs every hour at minute 30)
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/example_2_native_time/query_tags_by_time.sql
```

## Step 7: Verify Results

Check CloudZero dashboard for allocated warehouse costs within 2 hours.

## Cloud Provider Options

### AWS
```bash
export SECRETS_PROVIDER=aws
pip install -r shared/requirements-aws.txt
```

### Azure
```bash
export SECRETS_PROVIDER=azure
pip install -r shared/requirements-azure.txt
```

### GCP
```bash
export SECRETS_PROVIDER=gcp
pip install -r shared/requirements-gcp.txt
```

## Troubleshooting

- **No data**: Check `ACCOUNT_USAGE` permissions
- **API errors**: Verify CloudZero API key
- **Connection issues**: Check Snowflake credentials
- **Questions**: Contact your CloudZero representative

## Next Steps

- **Customize metadata**: Modify the SQL view for your specific dimensions
- **Adjust timeframes**: Change the analysis period in the view
- **Add monitoring**: Set up alerts for collection failures

---

*Total setup time: ~5 minutes | Results visible: ~2 hours*