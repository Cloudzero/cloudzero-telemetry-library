-- Copyright (c) 2016-present, CloudZero, Inc. All rights reserved.
-- Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.

-- Snowflake Usage-Based Cost Allocation - Custom JSON Metadata Allocation
-- Allocates warehouse costs by query execution time using custom embedded metadata
-- Usage Metric: Query execution time in milliseconds
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
        10 * 365 * 24 AS max_hour_buckets -- 10 years of hourly buckets
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
        
        -- Time calculations with proper timezone handling
        CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ AS adj_end_time,
        DATEADD('ms', -1 * execution_time, CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ) AS adj_start_time,
        
        -- Usage metric: Execution time in milliseconds
        execution_time AS usage_value,
        
        -- Warehouse for filtering
        LOWER(warehouse_name) AS warehouse,
        
        -- Store raw values for debugging
        query_text,
        query_type
        
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    CROSS JOIN config
    WHERE 
        -- Filter to analysis period
        CONVERT_TIMEZONE('UTC', end_time)::TIMESTAMP_NTZ >= config.analysis_start_date
        -- Exclude cache hits (these don't consume compute resources)
        AND cluster_number IS NOT NULL
        -- Exclude queries with no execution time
        AND execution_time > 0
        -- Only include queries with our custom metadata format
        AND query_text LIKE '%/*QUERYDATA>%<QUERYDATA*/%'
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
        -- Only include queries that successfully parsed metadata
        AND q.element_name IS NOT NULL
        AND q.element_name != ''
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