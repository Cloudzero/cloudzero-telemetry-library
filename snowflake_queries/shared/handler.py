#!/usr/bin/env python3
# Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
# Licensed under the BSD-style license. See LICENSE file in the project root for full license information.

"""
Universal CloudZero telemetry handler for Snowflake cost allocation.
Works with all usage metrics and cloud providers.
"""

import argparse
import logging
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional

from dateutil.tz import tzutc

from util.secrets import get_secrets
from util.snowflake import SnowflakeConnectionManager, execute_file
from util.telemetry import CloudZeroTelemetryClient, TelemetryRecord, UnitCostGranularity
from util.json_utils import loads


# Configuration from environment variables
class Config:
    """Configuration management for telemetry collection."""
    
    def __init__(self):
        self.telemetry_url = os.getenv('TELEMETRY_URL', 'https://api.cloudzero.com')
        self.telemetry_secrets_id = os.getenv('TELEMETRY_SECRETS_ID', 'cloudzero_telemetry_secrets')
        self.snowflake_secrets_id = os.getenv('SNOWFLAKE_SECRETS_ID', 'snowflake_secrets')
        self.default_warehouse = os.getenv('DEFAULT_WAREHOUSE', 'COMPUTE_WH')
        self.max_records_per_call = int(os.getenv('MAX_RECORDS_PER_CALL', '3000'))
        self.data_latency_hours = int(os.getenv('DATA_LATENCY_HOURS', '1'))
        self.stream_name = os.getenv('STREAM_NAME', 'snowflake-telemetry')
        self.log_level = os.getenv('LOG_LEVEL', 'INFO')


def setup_logging(log_level: str = 'INFO'):
    """Configure logging for the application."""
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )


def collect_telemetry_records(snowflake_manager: SnowflakeConnectionManager,
                             sql_file: str,
                             date_range_start: datetime,
                             date_range_end: datetime,
                             stream_name: str) -> List[TelemetryRecord]:
    """
    Collect telemetry records from Snowflake view.
    
    Args:
        snowflake_manager: Snowflake connection manager
        sql_file: Path to SQL file containing view definition
        date_range_start: Start of date range for collection
        date_range_end: End of date range for collection
        stream_name: Name of telemetry stream
        
    Returns:
        List of telemetry records
    """
    logger = logging.getLogger(__name__)
    
    try:
        # Connect to Snowflake
        conn = snowflake_manager.connect()
        
        # First, execute the SQL file to ensure view exists
        logger.info(f"Creating/updating Snowflake view from: {sql_file}")
        execute_file(conn, sql_file)
        
        # Query the view for telemetry data
        query_sql = f"""
            SELECT element_name, timestamp, filter, value
            FROM OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME
            WHERE timestamp >= '{date_range_start.isoformat()}'
              AND timestamp < '{date_range_end.isoformat()}'
            ORDER BY timestamp DESC, element_name
        """
        
        logger.info(f"Collecting telemetry data from {date_range_start} to {date_range_end}")
        result = execute_file(conn, query_sql)
        
        # Convert to TelemetryRecord objects
        records = []
        for row in result:
            try:
                record = TelemetryRecord(
                    granularity=UnitCostGranularity.hourly,
                    element_name=row['element_name'],
                    timestamp=row['timestamp'],
                    filter=loads(row['filter']),
                    telemetry_stream=stream_name,
                    value=float(row['value'])
                )
                records.append(record)
            except Exception as e:
                logger.warning(f"Skipping invalid record: {e}")
                continue
        
        logger.info(f"Collected {len(records)} telemetry records")
        return records
        
    except Exception as e:
        logger.error(f"Failed to collect telemetry records: {e}")
        raise


def main():
    """Main entry point for telemetry collection."""
    parser = argparse.ArgumentParser(
        description='CloudZero Snowflake Telemetry Collection',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Collect telemetry using native time allocation
  python handler.py ../example_2_native_time/query_tags_by_time.sql
  
  # Collect telemetry using credits allocation
  python handler.py ../example_3_native_credits/query_tags_by_credits.sql
  
  # Collect telemetry with custom date range
  python handler.py --start "2024-01-01T00:00:00" --end "2024-01-01T01:00:00" query.sql
        """
    )
    
    parser.add_argument(
        'sql_file',
        help='Path to SQL file containing Snowflake view definition'
    )
    
    parser.add_argument(
        '--start',
        type=str,
        help='Start datetime for collection (ISO format, default: 1 hour ago)'
    )
    
    parser.add_argument(
        '--end',
        type=str,
        help='End datetime for collection (ISO format, default: now)'
    )
    
    parser.add_argument(
        '--stream-name',
        type=str,
        help='Telemetry stream name (default: from config)'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Collect data but do not send to CloudZero API'
    )
    
    parser.add_argument(
        '--test-connection',
        action='store_true',
        help='Test connections to Snowflake and CloudZero API'
    )
    
    parser.add_argument(
        '--log-level',
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        help='Logging level (default: from config)'
    )
    
    args = parser.parse_args()
    
    # Load configuration
    config = Config()
    
    # Setup logging
    log_level = args.log_level or config.log_level
    setup_logging(log_level)
    
    logger = logging.getLogger(__name__)
    logger.info("Starting CloudZero Snowflake telemetry collection")
    
    # Validate SQL file exists
    sql_file = Path(args.sql_file)
    if not sql_file.exists():
        logger.error(f"SQL file not found: {sql_file}")
        sys.exit(1)
    
    # Create managers
    snowflake_manager = SnowflakeConnectionManager(
        config.snowflake_secrets_id,
        config.default_warehouse
    )
    
    telemetry_client = CloudZeroTelemetryClient(
        config.telemetry_secrets_id,
        config.telemetry_url
    )
    
    # Test connections if requested
    if args.test_connection:
        logger.info("Testing connections...")
        
        # Test Snowflake
        try:
            conn = snowflake_manager.connect()
            logger.info("✓ Snowflake connection successful")
            snowflake_manager.close()
        except Exception as e:
            logger.error(f"✗ Snowflake connection failed: {e}")
            sys.exit(1)
        
        # Test CloudZero API
        try:
            telemetry_client.test_connection()
            logger.info("✓ CloudZero API connection successful")
        except Exception as e:
            logger.error(f"✗ CloudZero API connection failed: {e}")
            sys.exit(1)
        
        logger.info("All connections successful")
        sys.exit(0)
    
    # Determine date range
    if args.start and args.end:
        date_range_start = datetime.fromisoformat(args.start.replace('Z', '+00:00'))
        date_range_end = datetime.fromisoformat(args.end.replace('Z', '+00:00'))
    else:
        # Default: collect previous complete hour
        current_hour = datetime.now(tz=tzutc()).replace(minute=0, second=0, microsecond=0)
        date_range_start = current_hour - timedelta(hours=config.data_latency_hours + 1)
        date_range_end = date_range_start + timedelta(hours=1)
    
    logger.info(f"Collection period: {date_range_start} to {date_range_end}")
    
    # Stream name
    stream_name = args.stream_name or config.stream_name
    
    try:
        # Collect telemetry records
        records = collect_telemetry_records(
            snowflake_manager,
            str(sql_file),
            date_range_start,
            date_range_end,
            stream_name
        )
        
        if not records:
            logger.warning("No telemetry records collected")
            sys.exit(0)
        
        # Send to CloudZero API
        if args.dry_run:
            logger.info(f"DRY RUN: Would send {len(records)} records to CloudZero API")
            for record in records[:5]:  # Show first 5 records
                logger.info(f"Sample record: {record}")
        else:
            logger.info(f"Sending {len(records)} records to CloudZero API")
            telemetry_client.send_batch_records(records, config.max_records_per_call, stream_name)
            logger.info("Telemetry collection completed successfully")
        
    except Exception as e:
        logger.error(f"Telemetry collection failed: {e}")
        sys.exit(1)
    
    finally:
        # Clean up connections
        snowflake_manager.close()


if __name__ == '__main__':
    main()