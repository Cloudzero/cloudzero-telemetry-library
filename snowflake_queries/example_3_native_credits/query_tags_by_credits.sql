-- Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
-- Licensed under the BSD-style license. See LICENSE file in the project root for full license information.

-- Snowflake Usage-Based Cost Allocation - Native Credits Allocation
-- Allocates warehouse costs by Snowflake credits consumed using native metadata
-- Usage Metric: Snowflake credits consumed (direct cost correlation)
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

-- Extract query metadata and credits consumed from QUERY_HISTORY
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
        
        -- Usage metric: Credits consumed (direct cost correlation)
        -- Scale by 1000 to work with integer values (credits are usually small decimals)
        ROUND(COALESCE(credits_used_cloud_services, 0) * 1000, 0) AS credits_consumed_scaled,
        
        -- Warehouse for filtering
        LOWER(warehouse_name) AS warehouse,
        
        -- Additional metrics for context
        execution_time,
        bytes_scanned,
        query_type
        
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    CROSS JOIN config
    WHERE 
        -- Filter to analysis period
        CONVERT_TIMEZONE('UTC', start_time)::TIMESTAMP_NTZ >= config.analysis_start_date
        -- Only include queries that consumed credits
        AND COALESCE(credits_used_cloud_services, 0) > 0
        -- Exclude system queries
        AND query_type NOT IN ('SHOW', 'DESCRIBE', 'USE', 'EXPLAIN')
        -- Ensure valid warehouse
        AND warehouse_name IS NOT NULL
        -- Exclude queries with no execution time (likely errors)
        AND execution_time > 0
        -- Minimum credit threshold (0.001 credits = 1 scaled unit)
        AND COALESCE(credits_used_cloud_services, 0) >= 0.001
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

-- Allocate credits to hourly buckets
-- For credits, we allocate the full credit amount to the start hour
-- since credits are typically attributed to query start time
credits_per_hour AS (
    SELECT 
        q.element_name,
        q.warehouse,
        h.query_hour,
        -- Allocate full credits to the hour when query started
        CASE 
            WHEN h.query_hour = DATE_TRUNC('hour', q.adj_start_time) THEN q.credits_consumed_scaled
            ELSE 0
        END AS credits_allocated
        
    FROM queries q
    LEFT JOIN hours h
        ON h.query_hour = DATE_TRUNC('hour', q.adj_start_time)
    WHERE h.query_hour IS NOT NULL
),

-- Aggregate credits by element, hour, and warehouse
-- This creates the final telemetry records for CloudZero
result AS (
    SELECT 
        element_name,
        query_hour,
        warehouse,
        SUM(credits_allocated) AS total_credits_scaled
    FROM credits_per_hour
    GROUP BY element_name, query_hour, warehouse
    HAVING SUM(credits_allocated) > 0 -- Only include records with actual credit consumption
)

-- Final output in CloudZero telemetry format
SELECT 
    element_name,
    query_hour AS timestamp,
    -- CloudZero filter format - assumes custom dimension "Snowflake Warehouse"
    OBJECT_CONSTRUCT('custom:Snowflake Warehouse', ARRAY_CONSTRUCT(warehouse)) AS filter,
    -- Usage value: Total credits consumed (scaled by 1000)
    total_credits_scaled AS value
FROM result
WHERE 
    element_name IS NOT NULL 
    AND element_name != '' 
    AND warehouse IS NOT NULL
    -- Exclude records where all metadata fields are 'unknown'
    AND element_name != 'unknown||unknown||unknown||unknown||unknown'
ORDER BY timestamp DESC, element_name;