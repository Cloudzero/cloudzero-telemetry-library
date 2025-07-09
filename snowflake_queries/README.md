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
| Usage Metric | Description | Best For |
|-------------|-------------|----------|
| **Time-Based** | Query execution time | General workloads, intuitive understanding |
| **Credits-Based** | Snowflake credits consumed | Direct cost correlation, billing accuracy |
| **Data Volume-Based** | Bytes scanned | Storage-intensive workloads, data processing |
| **Composite** | Weighted combination | Complex environments, balanced allocation |

### Metadata Options (What dimensions costs are split across)
| Metadata Method | Dimensions | Best For |
|-----------------|------------|----------|
| **Native Snowflake** | Database, Schema, User, Role, Query Tag | Quick setup, existing metadata |
| **Custom JSON** | Your embedded metadata | Custom business dimensions |

## Examples

| Example | Usage Metric | Metadata | Allocation Method |
|---------|-------------|----------|-------------------|
| [Native Time](example_2_native_time/) | Query execution time | Native Snowflake | Warehouse cost per millisecond |
| [Native Credits](example_3_native_credits/) | Credits consumed | Native Snowflake | Warehouse cost per credit |
| [Native Data Volume](example_4_native_data_volume/) | Bytes scanned | Native Snowflake | Warehouse cost per byte |
| [Native Composite](example_5_native_composite/) | Weighted combination | Native Snowflake | Warehouse cost per composite score |
| [Custom JSON](example_1_custom_json/) | Query execution time | Custom metadata | Warehouse cost per millisecond (custom dimensions) |

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

## Need Help?

Contact your CloudZero representative for assistance with setup or configuration.

---

*Results appear in CloudZero dashboard as allocated warehouse costs by your chosen dimensions within 2 hours of setup.*