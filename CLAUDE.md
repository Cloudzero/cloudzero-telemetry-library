# CloudZero Telemetry Library - Development Context

## Project Overview
This project provides examples and tools for CloudZero prospects and customers to collect telemetry data and transmit it to the CloudZero telemetry stream API. The primary use cases are:

1. **Usage-based splits** of shared cloud costs (primary focus)
2. **Unit metric analysis** (e.g., cost per 1M ad impressions)

## Current Focus: Snowflake Telemetry Enhancement
We're improving the Snowflake query telemetry example with:
- Enhanced documentation
- Snowflake tags support
- Additional Snowflake elements for cost allocation

## Project Structure

### Core Components
- `snowflake_queries/` - Main Snowflake telemetry implementation
  - `handler.py` - Python script for collecting and sending telemetry
  - `query_execution_time.sql` - SQL view for query metadata extraction
  - `query_tags.sql` - Alternative SQL view using native Snowflake tags
  - `constants.py` - Configuration constants
  - `util/` - Utility modules (AWS, Snowflake, JSON handling)

### Key Files
- `handler.py:86` - Main entry point for telemetry collection
- `query_execution_time.sql:11` - Custom JSON metadata extraction
- `query_tags.sql:16` - Native Snowflake tag-based metadata
- `util/snowflake.py:18` - Snowflake connection management

## Development Principles
All code must adhere to:
- **KISS** (Keep It Simple, Stupid)
- **DRY** (Don't Repeat Yourself)
- **SRP** (Single Responsibility Principle)
- **Open/Closed Principle**
- **Modular** design
- **Reusable** components
- **Efficient** implementation
- **Maintainable** code
- **Well-commented** and documented

## Current Implementation Analysis

### Existing Approach
The current implementation uses two methods for query metadata:

1. **Custom JSON Metadata** (`query_execution_time.sql`)
   - Embeds JSON in SQL comments: `/*QUERYDATA>{"key":"value"}<QUERYDATA*/`
   - Parses using regex: `REGEXP_SUBSTR(query_text, '/\\*QUERYDATA>(\\{.*\\})<QUERYDATA\\*/', 1, 1, 'e')`
   - Requires manual tagging of queries

2. **Native Snowflake Tags** (`query_tags.sql`)
   - Uses built-in Snowflake metadata: `QUERY_TAG`, `DATABASE_NAME`, `SCHEMA_NAME`, etc.
   - Automatically captures context without manual tagging
   - More robust and easier to implement

### Architecture
- **Data Collection**: Snowflake ACCOUNT_USAGE.QUERY_HISTORY
- **Processing**: Python handler with AWS Secrets Manager integration
- **Telemetry API**: CloudZero's unit-cost telemetry endpoint
- **Scheduling**: Designed for hourly execution

## Common Commands

### Development
```bash
# Install dependencies
pip install -r snowflake_queries/requirements.txt

# Run handler locally
python snowflake_queries/handler.py
```

### Testing
Check README or search codebase for testing approach - no standard test framework identified.

### Code Quality
- **Linting**: Use appropriate linter for Python (likely flake8 or black)
- **Type Checking**: Type hints already implemented, use mypy if available

## CloudZero Integration
- **API Endpoint**: `https://api.cloudzero.com/unit-cost/v1/telemetry`
- **Authentication**: API key via AWS Secrets Manager
- **Telemetry Format**: JSON records with granularity, element_name, filter, value, timestamp
- **Custom Dimensions**: "Snowflake Warehouse" for cost allocation

## Next Steps
1. Enhance documentation with clearer examples
2. Improve Snowflake tags support 
3. Add support for additional Snowflake elements (tables, databases, users, roles)
4. Create comprehensive examples for different use cases
5. Implement better error handling and logging

## Notes
- All secrets stored in AWS Secrets Manager
- Designed for prospects/customers to customize for their needs
- Focus on usage-based cost allocation for shared Snowflake compute
- Hourly data collection with 1-hour latency built-in