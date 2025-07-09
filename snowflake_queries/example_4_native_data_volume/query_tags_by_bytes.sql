-- Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
-- Licensed under the BSD-style license. See LICENSE file in the project root for full license information.

-- Snowflake Usage-Based Cost Allocation - Native Data Volume Allocation
-- Allocates warehouse costs by data volume processed using native metadata
-- Usage Metric: Bytes scanned during query execution
-- Metadata: DATABASE_NAME, SCHEMA_NAME, USER_NAME, ROLE_NAME, QUERY_TAG

CREATE OR REPLACE VIEW OPERATIONS.CLOUDZERO_TELEMETRY.QUERY_EXECUTION_TIME (
    ELEMENT_NAME,
    TIMESTAMP,
    FILTER,
    VALUE
) AS
WITH 
-- Configuration: Modify these parameters for your environment
config AS (
    SELECT 
        DATEADD('month', -6, CURRENT_TIMESTAMP())::TIMESTAMP_NTZ AS analysis_start_date,
        DATEADD('year', -10, CURRENT_TIMESTAMP())::TIMESTAMP_NTZ AS hour_generation_start,
        10 * 365 * 24 AS max_hour_buckets -- 10 years of hourly buckets
),

-- Extract query metadata and data volume from QUERY_HISTORY
-- Uses native Snowflake fields for cost allocation dimensions
queries AS (
    SELECT 
        -- Native Snowflake metadata fields
        QUERY_ID,
        COALESCE(DATABASE_NAME, 'unknown') AS database_name,
        COALESCE(SCHEMA_NAME, 'unknown') AS schema_name,
        COALESCE(USER_NAME, 'unknown') AS user_name,
        COALESCE(QUERY_TAG, 'unknown') AS query_tag,
        COALESCE(ROLE_NAME, 'unknown') AS role_name,
        
        -- Create element name for cost allocation
        -- This determines the dimensions across which costs are split
        ARRAY_TO_STRING(ARRAY_CONSTRUCT(
            COALESCE(DATABASE_NAME, 'unknown'),
            COALESCE(SCHEMA_NAME, 'unknown'),
            COALESCE(USER_NAME, 'unknown'),
            COALESCE(QUERY_TAG, 'unknown'),
            COALESCE(ROLE_NAME, 'unknown')
        ), '||') AS element_name,
        
        -- Time calculations for hourly bucketing
        CONVERT_TIMEZONE('UTC', start_time)::TIMESTAMP_NTZ AS adj_start_time,
        CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ AS adj_end_time,
        
        -- Usage metric: Bytes scanned (data volume processed)
        -- Scale down by 1MB (1,000,000 bytes) to work with manageable numbers
        ROUND(COALESCE(bytes_scanned, 0) / 1000000, 2) AS bytes_scanned_mb,
        
        -- Warehouse for filtering
        LOWER(warehouse_name) AS warehouse,
        
        -- Additional metrics for context
        execution_time,
        query_type,
        -- Cache hit percentage for analysis
        COALESCE(percentage_scanned_from_cache, 0) AS cache_hit_percentage
        
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    CROSS JOIN config
    WHERE 
        -- Filter to analysis period
        CONVERT_TIMEZONE('UTC', start_time)::TIMESTAMP_NTZ >= config.analysis_start_date
        -- Only include queries that scanned data
        AND COALESCE(bytes_scanned, 0) > 0
        -- Exclude system queries
        AND query_type NOT IN ('SHOW', 'DESCRIBE', 'USE', 'EXPLAIN')
        -- Ensure valid warehouse
        AND warehouse_name IS NOT NULL
        -- Exclude queries with no execution time (likely errors)
        AND execution_time > 0
        -- Minimum data scan threshold (1MB = 1,000,000 bytes)
        AND COALESCE(bytes_scanned, 0) >= 1000000
        -- Optionally exclude very high cache hit queries (uncomment if desired)
        -- AND COALESCE(percentage_scanned_from_cache, 0) < 95
),

-- Generate hourly time buckets for consistent aggregation
hours AS (
    SELECT 
        DATEADD('hour', 
               ROW_NUMBER() OVER (ORDER BY NULL), 
               DATE_TRUNC('hour', config.hour_generation_start)
        ) AS query_hour
    FROM TABLE(GENERATOR(ROWCOUNT => (SELECT max_hour_buckets FROM config)))
    CROSS JOIN config
    QUALIFY query_hour < CURRENT_TIMESTAMP()
),

-- Allocate data volume to hourly buckets
-- For data volume, we allocate the full amount to the start hour
-- since data scanning typically occurs at query start
bytes_per_hour AS (
    SELECT 
        q.element_name,
        q.warehouse,
        h.query_hour,
        -- Allocate full data volume to the hour when query started
        CASE 
            WHEN h.query_hour = DATE_TRUNC('hour', q.adj_start_time) THEN q.bytes_scanned_mb
            ELSE 0
        END AS bytes_allocated_mb
        
    FROM queries q
    LEFT JOIN hours h
        ON h.query_hour = DATE_TRUNC('hour', q.adj_start_time)
    WHERE h.query_hour IS NOT NULL
),

-- Aggregate data volume by element, hour, and warehouse
-- This creates the final telemetry records for CloudZero
result AS (
    SELECT 
        element_name,
        query_hour,
        warehouse,
        SUM(bytes_allocated_mb) AS total_bytes_scanned_mb
    FROM bytes_per_hour
    GROUP BY element_name, query_hour, warehouse
    HAVING SUM(bytes_allocated_mb) > 0 -- Only include records with actual data volume
)

-- Final output in CloudZero telemetry format
SELECT 
    element_name,
    query_hour AS timestamp,
    -- CloudZero filter format - assumes custom dimension "Snowflake Warehouse"
    OBJECT_CONSTRUCT('custom:Snowflake Warehouse', ARRAY_CONSTRUCT(warehouse)) AS filter,
    -- Usage value: Total data volume scanned in MB
    total_bytes_scanned_mb AS value
FROM result
WHERE 
    element_name IS NOT NULL 
    AND element_name != '' 
    AND warehouse IS NOT NULL
    -- Exclude records where all metadata fields are 'unknown'
    AND element_name != 'unknown||unknown||unknown||unknown||unknown'
ORDER BY timestamp DESC, element_name;