# Shared Multi-Cloud Python Setup

Universal Python handler for Snowflake telemetry collection across all cloud providers.

## Overview

The shared Python handler works with all examples and supports multiple cloud providers:
- **Environment Variables**: Works everywhere (default)
- **AWS**: AWS Secrets Manager integration
- **Azure**: Azure Key Vault integration
- **GCP**: Google Secret Manager integration

## Quick Setup (Environment Variables)

```bash
# Set credentials
export CLOUDZERO_API_KEY="your-api-key"
export SNOWFLAKE_USER="your-user"
export SNOWFLAKE_PASSWORD="your-password"
export SNOWFLAKE_ACCOUNT="your-account"
export SECRETS_PROVIDER="env"

# Install dependencies
pip install -r requirements.txt

# Run with any example
python handler.py ../example_2_native_time/query_tags_by_time.sql
```

## Cloud Provider Setup

### AWS Secrets Manager

```bash
# Set provider
export SECRETS_PROVIDER="aws"

# Install AWS dependencies
pip install -r requirements.txt -r requirements-aws.txt

# Create secrets in AWS
aws secretsmanager create-secret \
    --name cloudzero_telemetry_secrets \
    --secret-string '{"external_api_key": "your-api-key"}'

aws secretsmanager create-secret \
    --name snowflake_secrets \
    --secret-string '{"user": "your-user", "password": "your-password", "account": "your-account"}'

# Run handler
python handler.py ../example_2_native_time/query_tags_by_time.sql
```

### Azure Key Vault

```bash
# Set provider
export SECRETS_PROVIDER="azure"

# Install Azure dependencies
pip install -r requirements.txt -r requirements-azure.txt

# Configure Azure authentication
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_VAULT_URL="https://your-vault.vault.azure.net/"

# Run handler
python handler.py ../example_2_native_time/query_tags_by_time.sql
```

### Google Cloud Secret Manager

```bash
# Set provider
export SECRETS_PROVIDER="gcp"

# Install GCP dependencies
pip install -r requirements.txt -r requirements-gcp.txt

# Configure GCP authentication
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
export GCP_PROJECT_ID="your-project-id"

# Run handler
python handler.py ../example_2_native_time/query_tags_by_time.sql
```

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRETS_PROVIDER` | Secrets management provider | `env` |
| `CLOUDZERO_API_KEY` | CloudZero API key | Required |
| `SNOWFLAKE_USER` | Snowflake username | Required |
| `SNOWFLAKE_PASSWORD` | Snowflake password | Required |
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier | Required |
| `TELEMETRY_URL` | CloudZero telemetry API URL | `https://api.cloudzero.com/unit-cost/v1/telemetry` |
| `MAX_RECORDS_PER_CALL` | Batch size for API calls | `3000` |
| `DEFAULT_WAREHOUSE` | Default Snowflake warehouse | `COMPUTE_WH` |
| `DATA_LATENCY_HOURS` | Data processing delay | `1` |

### Scheduling

Set up hourly execution using your preferred scheduler:

```bash
# Cron (Linux/Mac)
30 * * * * /path/to/python /path/to/shared/handler.py /path/to/example/query.sql

# Task Scheduler (Windows)
# Create task to run every hour at minute 30

# Kubernetes CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: snowflake-telemetry
spec:
  schedule: "30 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: telemetry-collector
            image: python:3.9
            command: ["python", "/app/shared/handler.py", "/app/example_2_native_time/query_tags_by_time.sql"]
```

## Troubleshooting

### Common Issues

- **Connection failed**: Check Snowflake credentials and network connectivity
- **API errors**: Verify CloudZero API key and telemetry URL
- **No data**: Confirm Snowflake view exists and returns data
- **Permission errors**: Check ACCOUNT_USAGE access for Snowflake user

### Debugging

Enable debug logging:

```bash
export LOG_LEVEL="DEBUG"
python handler.py ../example_2_native_time/query_tags_by_time.sql
```

### Secrets Provider Issues

- **AWS**: Check IAM permissions for Secrets Manager
- **Azure**: Verify Key Vault access and authentication
- **GCP**: Confirm Secret Manager API is enabled and service account has access
- **Environment**: Verify all required variables are set

## Dependencies

### Core Requirements (requirements.txt)
```
snowflake-connector-python>=3.0.0
requests>=2.28.0
python-dateutil>=2.8.0
toolz>=0.12.0
simplejson>=3.17.0
```

### Cloud Provider Requirements
- **AWS**: `boto3>=1.26.0` (requirements-aws.txt)
- **Azure**: `azure-keyvault-secrets>=4.7.0, azure-identity>=1.12.0` (requirements-azure.txt)
- **GCP**: `google-cloud-secret-manager>=2.16.0` (requirements-gcp.txt)

## Architecture

- **handler.py**: Main entry point and orchestration
- **util/secrets.py**: Multi-cloud secrets management
- **util/snowflake.py**: Snowflake connection and query execution
- **util/telemetry.py**: CloudZero API integration
- **util/json.py**: JSON serialization utilities

## Need Help?

Contact your CloudZero representative for assistance with setup or configuration.

---

*One Python codebase | All cloud providers | All examples*