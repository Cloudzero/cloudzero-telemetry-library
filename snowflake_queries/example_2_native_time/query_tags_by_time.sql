-- Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
-- Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.

-- Snowflake Usage-Based Cost Allocation - Native Time Allocation
-- Allocates warehouse costs by query execution time using native Snowflake metadata
-- Usage Metric: Query execution time in milliseconds
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

-- Extract query metadata and execution time from QUERY_HISTORY
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
        
        -- Time calculations with proper timezone handling
        CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ AS adj_end_time,
        DATEADD('ms', -1 * execution_time, CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ) AS adj_start_time,
        
        -- Usage metric: Execution time in milliseconds
        execution_time AS usage_value,
        
        -- Warehouse for filtering
        LOWER(warehouse_name) AS warehouse
        
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    CROSS JOIN config
    WHERE 
        -- Filter to analysis period
        CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ >= config.analysis_start_date
        -- Exclude cache hits (these don't consume compute resources)
        AND cluster_number IS NOT NULL
        -- Exclude queries with no execution time
        AND execution_time > 0
        -- Exclude system queries that don't represent user workload
        AND query_type NOT IN ('SHOW', 'DESCRIBE', 'USE', 'EXPLAIN')
        -- Ensure we have a valid warehouse
        AND warehouse_name IS NOT NULL
        -- Exclude very short queries (likely metadata operations)
        AND execution_time > 100 -- Minimum 100ms
),

-- Generate hourly time buckets for consistent aggregation
-- This ensures we have hourly cost allocation points
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

-- Split multi-hour queries into hourly segments
-- This ensures accurate cost allocation when queries span multiple hours
time_per_query_in_hour AS (
    SELECT 
        q.adj_start_time AS start_time,
        q.adj_end_time AS end_time,
        q.element_name,
        q.warehouse,
        h.query_hour,
        
        -- Calculate the portion of execution time that falls within this hour
        -- Uses GREATEST/LEAST to handle edge cases properly
        GREATEST(0, 
            DATEDIFF('ms', 
                GREATEST(q.adj_start_time, h.query_hour),
                LEAST(q.adj_end_time, DATEADD('hour', 1, h.query_hour))
            )
        ) AS query_time_ms
        
    FROM queries q
    LEFT JOIN hours h
        ON h.query_hour >= DATE_TRUNC('hour', q.adj_start_time)
        AND h.query_hour < q.adj_end_time
    WHERE 
        -- Only include rows where the query actually overlaps with the hour
        h.query_hour IS NOT NULL
        AND DATEDIFF('ms', 
            GREATEST(q.adj_start_time, h.query_hour),
            LEAST(q.adj_end_time, DATEADD('hour', 1, h.query_hour))
        ) > 0
),

-- Aggregate execution time by element, hour, and warehouse
-- This creates the final telemetry records for CloudZero
result AS (
    SELECT 
        element_name,
        query_hour,
        warehouse,
        SUM(query_time_ms) AS total_execution_time_ms
    FROM time_per_query_in_hour
    GROUP BY element_name, query_hour, warehouse
    HAVING SUM(query_time_ms) > 0 -- Only include records with actual execution time
)

-- Final output in CloudZero telemetry format
SELECT 
    element_name,
    query_hour AS timestamp,
    -- CloudZero filter format - assumes custom dimension "Snowflake Warehouse"
    OBJECT_CONSTRUCT('custom:Snowflake Warehouse', ARRAY_CONSTRUCT(warehouse)) AS filter,
    -- Usage value: Total execution time in milliseconds
    total_execution_time_ms AS value
FROM result
WHERE 
    element_name IS NOT NULL 
    AND element_name != '' 
    AND warehouse IS NOT NULL
    -- Exclude records where all metadata fields are 'unknown'
    AND element_name != 'unknown||unknown||unknown||unknown||unknown'
ORDER BY timestamp DESC, element_name;