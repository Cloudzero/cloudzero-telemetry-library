# Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
# Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.

"""
Multi-cloud secrets management for CloudZero telemetry collection.
Supports AWS, Azure, GCP, and environment variables.
"""

import os
import json
import logging
from abc import ABC, abstractmethod
from typing import Dict, Any

logger = logging.getLogger(__name__)


class SecretsManager(ABC):
    """Abstract base class for secrets management providers."""
    
    @abstractmethod
    def get_secrets(self, secret_id: str) -> Dict[str, Any]:
        """Retrieve secrets for the given secret ID."""
        pass


class EnvironmentSecretsManager(SecretsManager):
    """Environment variables secrets manager (default, works everywhere)."""
    
    def get_secrets(self, secret_id: str) -> Dict[str, Any]:
        """Get secrets from environment variables."""
        logger.debug(f"Getting secrets from environment variables for: {secret_id}")
        
        if secret_id == 'cloudzero_telemetry_secrets':
            api_key = os.getenv('CLOUDZERO_API_KEY')
            if not api_key:
                raise ValueError("CLOUDZERO_API_KEY environment variable is required")
            return {'external_api_key': api_key}
            
        elif secret_id == 'snowflake_secrets':
            user = os.getenv('SNOWFLAKE_USER')
            password = os.getenv('SNOWFLAKE_PASSWORD')
            account = os.getenv('SNOWFLAKE_ACCOUNT')
            
            if not all([user, password, account]):
                raise ValueError(
                    "SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, and SNOWFLAKE_ACCOUNT "
                    "environment variables are required"
                )
            
            return {
                'user': user,
                'password': password,
                'account': account
            }
        
        else:
            raise ValueError(f"Unknown secret ID: {secret_id}")


class AWSSecretsManager(SecretsManager):
    """AWS Secrets Manager integration."""
    
    def __init__(self):
        try:
            import boto3
            self.client = boto3.client('secretsmanager')
        except ImportError:
            raise ImportError(
                "boto3 is required for AWS Secrets Manager. "
                "Install with: pip install boto3"
            )
    
    def get_secrets(self, secret_id: str) -> Dict[str, Any]:
        """Get secrets from AWS Secrets Manager."""
        logger.debug(f"Getting secrets from AWS Secrets Manager for: {secret_id}")
        
        try:
            response = self.client.get_secret_value(SecretId=secret_id)
            secret_string = response['SecretString']
            return json.loads(secret_string)
        except Exception as e:
            logger.error(f"Failed to retrieve secret {secret_id} from AWS: {e}")
            raise


class AzureSecretsManager(SecretsManager):
    """Azure Key Vault integration."""
    
    def __init__(self):
        try:
            from azure.keyvault.secrets import SecretClient
            from azure.identity import DefaultAzureCredential
            
            vault_url = os.getenv('AZURE_VAULT_URL')
            if not vault_url:
                raise ValueError("AZURE_VAULT_URL environment variable is required")
            
            credential = DefaultAzureCredential()
            self.client = SecretClient(vault_url=vault_url, credential=credential)
        except ImportError:
            raise ImportError(
                "azure-keyvault-secrets and azure-identity are required for Azure Key Vault. "
                "Install with: pip install azure-keyvault-secrets azure-identity"
            )
    
    def get_secrets(self, secret_id: str) -> Dict[str, Any]:
        """Get secrets from Azure Key Vault."""
        logger.debug(f"Getting secrets from Azure Key Vault for: {secret_id}")
        
        try:
            secret = self.client.get_secret(secret_id)
            return json.loads(secret.value)
        except Exception as e:
            logger.error(f"Failed to retrieve secret {secret_id} from Azure: {e}")
            raise


class GCPSecretsManager(SecretsManager):
    """Google Cloud Secret Manager integration."""
    
    def __init__(self):
        try:
            from google.cloud import secretmanager
            
            project_id = os.getenv('GCP_PROJECT_ID')
            if not project_id:
                raise ValueError("GCP_PROJECT_ID environment variable is required")
            
            self.client = secretmanager.SecretManagerServiceClient()
            self.project_id = project_id
        except ImportError:
            raise ImportError(
                "google-cloud-secret-manager is required for GCP Secret Manager. "
                "Install with: pip install google-cloud-secret-manager"
            )
    
    def get_secrets(self, secret_id: str) -> Dict[str, Any]:
        """Get secrets from Google Cloud Secret Manager."""
        logger.debug(f"Getting secrets from GCP Secret Manager for: {secret_id}")
        
        try:
            name = f"projects/{self.project_id}/secrets/{secret_id}/versions/latest"
            response = self.client.access_secret_version(request={"name": name})
            secret_string = response.payload.data.decode("UTF-8")
            return json.loads(secret_string)
        except Exception as e:
            logger.error(f"Failed to retrieve secret {secret_id} from GCP: {e}")
            raise


class SecretsManagerFactory:
    """Factory for creating secrets managers based on provider."""
    
    @staticmethod
    def get_manager(provider: str = None) -> SecretsManager:
        """Get secrets manager for the specified provider."""
        if provider is None:
            provider = os.getenv('SECRETS_PROVIDER', 'env')
        
        provider = provider.lower()
        
        if provider == 'env':
            return EnvironmentSecretsManager()
        elif provider == 'aws':
            return AWSSecretsManager()
        elif provider == 'azure':
            return AzureSecretsManager()
        elif provider == 'gcp':
            return GCPSecretsManager()
        else:
            raise ValueError(
                f"Unsupported secrets provider: {provider}. "
                f"Supported providers: env, aws, azure, gcp"
            )


# Convenience function for backward compatibility
def get_secrets(secret_id: str) -> Dict[str, Any]:
    """Get secrets using the configured provider."""
    manager = SecretsManagerFactory.get_manager()
    return manager.get_secrets(secret_id)