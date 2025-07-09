# Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
# Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.

"""
CloudZero telemetry API integration with retry logic and error handling.
"""

import logging
import time
from datetime import datetime
from enum import Enum
from typing import NamedTuple, Dict, List, Optional
from urllib.parse import urljoin

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .secrets import get_secrets
from .json_utils import serializable

logger = logging.getLogger(__name__)


class UnitCostGranularity(Enum):
    """Supported granularities for unit cost telemetry."""
    hourly = 'hourly'
    daily = 'daily'


class TelemetryRecord(NamedTuple):
    """Represents a telemetry record for CloudZero API."""
    granularity: UnitCostGranularity
    element_name: str
    filter: Dict[str, List[str]]
    telemetry_stream: str
    value: float
    timestamp: datetime


class CloudZeroTelemetryClient:
    """Client for CloudZero telemetry API with retry logic and error handling."""
    
    def __init__(self, secrets_id: str = 'cloudzero_telemetry_secrets', 
                 base_url: str = 'https://api.cloudzero.com',
                 timeout: int = 30,
                 max_retries: int = 3):
        """
        Initialize CloudZero telemetry client.
        
        Args:
            secrets_id: Secrets identifier for API key
            base_url: Base URL for CloudZero API
            timeout: Request timeout in seconds
            max_retries: Maximum number of retry attempts
        """
        self.secrets_id = secrets_id
        self.base_url = base_url
        self.timeout = timeout
        self.max_retries = max_retries
        
        # Configure session with retry strategy
        self.session = requests.Session()
        retry_strategy = Retry(
            total=max_retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["POST"]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
        
        # Get API key
        self._api_key = None
        self._get_api_key()
    
    def _get_api_key(self):
        """Retrieve API key from secrets."""
        try:
            secrets = get_secrets(self.secrets_id)
            self._api_key = secrets['external_api_key']
            logger.debug("Successfully retrieved CloudZero API key")
        except Exception as e:
            logger.error(f"Failed to retrieve CloudZero API key: {e}")
            raise
    
    def send_telemetry_records(self, records: List[TelemetryRecord], 
                              stream_name: str = 'snowflake-telemetry') -> bool:
        """
        Send telemetry records to CloudZero API.
        
        Args:
            records: List of telemetry records to send
            stream_name: Name of the telemetry stream
            
        Returns:
            True if successful, raises exception on failure
        """
        if not records:
            logger.warning("No telemetry records to send")
            return True
        
        url = urljoin(self.base_url, '/unit-cost/v1/telemetry')
        
        # Prepare payload
        payload = {
            'records': [
                {
                    'granularity': record.granularity.value,
                    'element-name': record.element_name,
                    'filter': record.filter,
                    'telemetry-stream': record.telemetry_stream,
                    'value': record.value,
                    'timestamp': record.timestamp.isoformat()
                }
                for record in records
            ]
        }
        
        # Serialize payload
        try:
            serialized_payload = serializable(payload)
        except Exception as e:
            logger.error(f"Failed to serialize telemetry payload: {e}")
            raise
        
        headers = {
            'Authorization': self._api_key,
            'Content-Type': 'application/json',
            'User-Agent': 'CloudZero-Snowflake-Telemetry/1.0'
        }
        
        logger.info(f"Sending {len(records)} telemetry records to {url}")
        start_time = time.time()
        
        try:
            response = self.session.post(
                url,
                json=serialized_payload,
                headers=headers,
                timeout=self.timeout
            )
            
            elapsed_time = time.time() - start_time
            
            if response.ok:
                logger.info(f"Successfully sent {len(records)} records in {elapsed_time:.2f}s")
                return True
            else:
                logger.error(f"Failed to send telemetry: {response.status_code} - {response.text}")
                logger.error(f"Request took {elapsed_time:.2f}s")
                response.raise_for_status()
                
        except requests.exceptions.RequestException as e:
            elapsed_time = time.time() - start_time
            logger.error(f"Request failed after {elapsed_time:.2f}s: {e}")
            raise
        except Exception as e:
            elapsed_time = time.time() - start_time
            logger.error(f"Unexpected error after {elapsed_time:.2f}s: {e}")
            raise
    
    def send_batch_records(self, records: List[TelemetryRecord], 
                          batch_size: int = 3000,
                          stream_name: str = 'snowflake-telemetry') -> bool:
        """
        Send telemetry records in batches.
        
        Args:
            records: List of telemetry records to send
            batch_size: Maximum records per batch
            stream_name: Name of the telemetry stream
            
        Returns:
            True if all batches successful
        """
        if not records:
            logger.warning("No telemetry records to send")
            return True
        
        logger.info(f"Sending {len(records)} records in batches of {batch_size}")
        
        # Split records into batches
        batches = [records[i:i + batch_size] for i in range(0, len(records), batch_size)]
        
        for i, batch in enumerate(batches, 1):
            logger.info(f"Sending batch {i}/{len(batches)} ({len(batch)} records)")
            
            try:
                self.send_telemetry_records(batch, stream_name)
            except Exception as e:
                logger.error(f"Failed to send batch {i}/{len(batches)}: {e}")
                raise
        
        logger.info(f"Successfully sent all {len(records)} records in {len(batches)} batches")
        return True
    
    def test_connection(self) -> bool:
        """
        Test connection to CloudZero API.
        
        Returns:
            True if connection successful, False otherwise
        """
        try:
            # Send a minimal test record
            test_record = TelemetryRecord(
                granularity=UnitCostGranularity.hourly,
                element_name='test-connection',
                filter={'test': ['connection']},
                telemetry_stream='test-stream',
                value=0.0,
                timestamp=datetime.utcnow()
            )
            
            self.send_telemetry_records([test_record])
            logger.info("CloudZero API connection test successful")
            return True
            
        except Exception as e:
            logger.error(f"CloudZero API connection test failed: {e}")
            return False


# Convenience functions for backward compatibility
def send_telemetry_records(records: List[TelemetryRecord], 
                          stream_name: str = 'snowflake-telemetry') -> bool:
    """Send telemetry records using default client."""
    client = CloudZeroTelemetryClient()
    return client.send_batch_records(records, stream_name=stream_name)