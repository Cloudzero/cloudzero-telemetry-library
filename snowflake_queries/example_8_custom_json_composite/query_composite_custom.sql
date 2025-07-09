-- Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
-- Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.

-- Snowflake Usage-Based Cost Allocation - Custom JSON Composite Allocation
-- Allocates warehouse costs using weighted combination of multiple usage metrics with custom metadata
-- Usage Metric: Composite score (execution time + credits + data volume)
-- Metadata: Custom JSON embedded in query comments (customer_id, team, project, etc.)
-- Query Format: SELECT /*QUERYDATA>{"customer_id": "abc", "team": "analytics"}<QUERYDATA*/ ...

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
        10 * 365 * 24 AS max_hour_buckets, -- 10 years of hourly buckets
        
        -- Composite scoring weights (must sum to 1.0)
        -- Adjust these weights based on your organizational priorities
        0.4 AS time_weight,        -- 40% weight for execution time
        0.4 AS credits_weight,     -- 40% weight for credits consumed
        0.2 AS data_volume_weight  -- 20% weight for data volume
),

-- Extract and parse custom JSON metadata from query text
-- This approach requires queries to embed metadata in a specific comment format
queries AS (
    SELECT 
        -- Query identification
        QUERY_ID,
        
        -- Extract JSON metadata from query text using regex
        -- Pattern: /*QUERYDATA>{"key": "value", ...}<QUERYDATA*/
        REGEXP_SUBSTR(query_text, '/\\*QUERYDATA>(\\{.*?\\})<QUERYDATA\\*/', 1, 1, 'e') AS json_string,
        
        -- Parse the extracted JSON with error handling
        CASE 
            WHEN json_string IS NOT NULL AND json_string != '' THEN
                TRY_PARSE_JSON(json_string)
            ELSE NULL
        END AS query_data,
        
        -- Extract specific metadata properties (customize these for your use case)
        -- Common examples: customer_id, team, project, environment, service, etc.
        COALESCE(query_data:customer_id::string, 'unknown') AS customer_id,
        COALESCE(query_data:team::string, 'unknown') AS team,
        COALESCE(query_data:project::string, 'unknown') AS project,
        COALESCE(query_data:environment::string, 'unknown') AS environment,
        COALESCE(query_data:service::string, 'unknown') AS service,
        
        -- Create element name from extracted metadata
        -- This determines the dimensions across which costs are split
        ARRAY_TO_STRING(ARRAY_CONSTRUCT(
            COALESCE(query_data:customer_id::string, 'unknown'),
            COALESCE(query_data:team::string, 'unknown'),
            COALESCE(query_data:project::string, 'unknown'),
            COALESCE(query_data:environment::string, 'unknown'),
            COALESCE(query_data:service::string, 'unknown')
        ), '||') AS element_name,
        
        -- Time calculations for hourly bucketing
        CONVERT_TIMEZONE('UTC', start_time)::TIMESTAMP_NTZ AS adj_start_time,
        CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ AS adj_end_time,
        
        -- Individual usage metrics (normalized for composite scoring)
        execution_time AS exec_time_ms,
        COALESCE(credits_used_cloud_services, 0) * 1000 AS credits_scaled,
        COALESCE(bytes_scanned, 0) / 1000000 AS bytes_scanned_mb,
        
        -- Warehouse for filtering
        LOWER(warehouse_name) AS warehouse,
        
        -- Store additional context for debugging
        query_text,
        query_type,
        COALESCE(percentage_scanned_from_cache, 0) AS cache_hit_percentage
        
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    CROSS JOIN config
    WHERE 
        -- Filter to analysis period
        CONVERT_TIMEZONE('UTC', start_time)::TIMESTAMP_NTZ >= config.analysis_start_date
        -- Only include queries with our custom metadata format
        AND query_text LIKE '%/*QUERYDATA>%<QUERYDATA*/%'
        -- Exclude system queries that don't represent user workload
        AND query_type NOT IN ('SHOW', 'DESCRIBE', 'USE', 'EXPLAIN')
        -- Ensure we have a valid warehouse
        AND warehouse_name IS NOT NULL
        -- Exclude queries with no execution time (likely errors)
        AND execution_time > 0
        -- Require at least one metric to have meaningful value
        AND (execution_time > 100 OR 
             COALESCE(credits_used_cloud_services, 0) >= 0.001 OR 
             COALESCE(bytes_scanned, 0) >= 1000000)
),

-- Calculate composite scores with weighted combination
composite_scores AS (
    SELECT 
        q.*,
        -- Calculate composite score using weighted combination
        -- Scale factors ensure metrics are in comparable ranges
        ROUND(
            (q.exec_time_ms * c.time_weight) +                    -- Time component
            (q.credits_scaled * c.credits_weight) +               -- Credits component  
            (q.bytes_scanned_mb * c.data_volume_weight),         -- Data volume component
            2
        ) AS composite_score
        
    FROM queries q
    CROSS JOIN config c
    WHERE 
        -- Only include queries that successfully parsed metadata
        q.element_name IS NOT NULL
        AND q.element_name != ''
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

-- Allocate composite scores to hourly buckets
-- For composite scores, we allocate the full score to the start hour
composite_per_hour AS (
    SELECT 
        q.element_name,
        q.warehouse,
        h.query_hour,
        -- Allocate full composite score to the hour when query started
        CASE 
            WHEN h.query_hour = DATE_TRUNC('hour', q.adj_start_time) THEN q.composite_score
            ELSE 0
        END AS composite_allocated
        
    FROM composite_scores q
    LEFT JOIN hours h
        ON h.query_hour = DATE_TRUNC('hour', q.adj_start_time)
    WHERE h.query_hour IS NOT NULL
),

-- Aggregate composite scores by element, hour, and warehouse
-- This creates the final telemetry records for CloudZero
result AS (
    SELECT 
        element_name,
        query_hour,
        warehouse,
        SUM(composite_allocated) AS total_composite_score
    FROM composite_per_hour
    GROUP BY element_name, query_hour, warehouse
    HAVING SUM(composite_allocated) > 0 -- Only include records with actual composite score
)

-- Final output in CloudZero telemetry format
SELECT 
    element_name,
    query_hour AS timestamp,
    -- CloudZero filter format - assumes custom dimension "Snowflake Warehouse"
    OBJECT_CONSTRUCT('custom:Snowflake Warehouse', ARRAY_CONSTRUCT(warehouse)) AS filter,
    -- Usage value: Total composite score (weighted combination)
    total_composite_score AS value
FROM result
WHERE 
    element_name IS NOT NULL 
    AND element_name != '' 
    AND warehouse IS NOT NULL
    -- Exclude records where all metadata fields are 'unknown'
    AND element_name != 'unknown||unknown||unknown||unknown||unknown'
ORDER BY timestamp DESC, element_name;