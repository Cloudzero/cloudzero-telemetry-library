# Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
# Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.

"""
Enhanced Snowflake utilities for CloudZero telemetry collection.
Includes connection management, query execution, and error handling.
"""

import logging
import time
from typing import Mapping, Any, List, cast, Optional

import snowflake.connector
from snowflake.connector import SnowflakeConnection
from snowflake.connector.errors import Error as SnowflakeError

from .secrets import get_secrets

DictRow = Mapping[str, Any]
QueryResult = List[DictRow]

logger = logging.getLogger(__name__)


class SnowflakeConnectionManager:
    """Manages Snowflake connections with retry logic and error handling."""
    
    def __init__(self, secrets_id: str, default_warehouse: str):
        self.secrets_id = secrets_id
        self.default_warehouse = default_warehouse
        self._connection = None
    
    def connect(self) -> SnowflakeConnection:
        """Establish connection to Snowflake with retry logic."""
        if self._connection and not self._connection.is_closed():
            return self._connection
        
        logger.info(f"Connecting to Snowflake using secrets: {self.secrets_id}")
        
        try:
            credentials = get_secrets(self.secrets_id)
            
            self._connection = snowflake.connector.connect(
                warehouse=self.default_warehouse,
                user=credentials['user'],
                account=credentials['account'],
                password=credentials['password'],
                application='CloudZero-Telemetry',
                client_session_keep_alive=True,
                login_timeout=30,
                network_timeout=30
            )
            
            logger.info("Successfully connected to Snowflake")
            return self._connection
            
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            raise
    
    def close(self):
        """Close the Snowflake connection."""
        if self._connection and not self._connection.is_closed():
            self._connection.close()
            logger.info("Snowflake connection closed")


def connect(secrets_id: str, default_warehouse: str) -> SnowflakeConnection:
    """Create a Snowflake connection (backward compatibility)."""
    manager = SnowflakeConnectionManager(secrets_id, default_warehouse)
    return manager.connect()


def execute(conn: SnowflakeConnection, sql: str, params: Optional[List] = None, 
           timeout: Optional[int] = None) -> QueryResult:
    """
    Execute SQL query with enhanced error handling and logging.
    
    Args:
        conn: Snowflake connection
        sql: SQL query to execute
        params: Optional query parameters for parameterized queries
        timeout: Optional timeout in seconds
        
    Returns:
        Query results as list of dictionaries
    """
    logger.debug(f"Executing query: {sql[:200]}{'...' if len(sql) > 200 else ''}")
    
    if params:
        logger.debug(f"Query parameters: {params}")
    
    start_time = time.time()
    
    try:
        with conn.cursor(snowflake.connector.DictCursor) as cursor:
            # Execute query with optional parameters
            if params:
                cursor.execute(sql, params, timeout=timeout)
            else:
                cursor.execute(sql, timeout=timeout)
            
            # Fetch results
            result = cast(List[dict], cursor.fetchall())
            
            # Normalize column names to lowercase
            normalized_result = [
                {k.lower(): v for k, v in row.items()} 
                for row in result
            ]
            
            execution_time = time.time() - start_time
            logger.info(f"Query executed successfully in {execution_time:.2f}s, returned {len(normalized_result)} rows")
            
            return normalized_result
            
    except SnowflakeError as e:
        execution_time = time.time() - start_time
        logger.error(f"Snowflake query failed after {execution_time:.2f}s: {e}")
        logger.error(f"Query: {sql}")
        raise
    except Exception as e:
        execution_time = time.time() - start_time
        logger.error(f"Unexpected error executing query after {execution_time:.2f}s: {e}")
        logger.error(f"Query: {sql}")
        raise


def execute_file(conn: SnowflakeConnection, file_path: str, 
                timeout: Optional[int] = None) -> QueryResult:
    """
    Execute SQL from a file.
    
    Args:
        conn: Snowflake connection
        file_path: Path to SQL file
        timeout: Optional timeout in seconds
        
    Returns:
        Query results as list of dictionaries
    """
    logger.info(f"Executing SQL from file: {file_path}")
    
    try:
        with open(file_path, 'r') as f:
            sql = f.read()
        
        return execute(conn, sql, timeout=timeout)
        
    except FileNotFoundError:
        logger.error(f"SQL file not found: {file_path}")
        raise
    except Exception as e:
        logger.error(f"Error executing SQL file {file_path}: {e}")
        raise


def test_connection(secrets_id: str, default_warehouse: str) -> bool:
    """
    Test Snowflake connection and return success status.
    
    Args:
        secrets_id: Secrets identifier
        default_warehouse: Default warehouse name
        
    Returns:
        True if connection successful, False otherwise
    """
    try:
        manager = SnowflakeConnectionManager(secrets_id, default_warehouse)
        conn = manager.connect()
        
        # Test with simple query
        execute(conn, "SELECT 1 AS test")
        manager.close()
        
        logger.info("Snowflake connection test successful")
        return True
        
    except Exception as e:
        logger.error(f"Snowflake connection test failed: {e}")
        return False


def get_account_info(conn: SnowflakeConnection) -> dict:
    """
    Get Snowflake account information for debugging.
    
    Args:
        conn: Snowflake connection
        
    Returns:
        Account information dictionary
    """
    try:
        result = execute(conn, """
            SELECT 
                CURRENT_ACCOUNT() AS account,
                CURRENT_USER() AS user,
                CURRENT_ROLE() AS role,
                CURRENT_WAREHOUSE() AS warehouse,
                CURRENT_DATABASE() AS database,
                CURRENT_SCHEMA() AS schema
        """)
        
        if result:
            return result[0]
        else:
            return {}
            
    except Exception as e:
        logger.error(f"Failed to get account info: {e}")
        return {}