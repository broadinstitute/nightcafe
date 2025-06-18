-- Example queries for the execution times database

-- 1. Overall processing statistics
SELECT 
    COUNT(*) as total_sites,
    MIN(wall_clock_time) as start_time,
    MAX(wall_clock_time) as end_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0, 2) as total_hours,
    ROUND(COUNT(*) / (EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0), 2) as sites_per_hour
FROM execution_data;

-- 2. Example: Check performance of a few specific modules
-- Only showing 3 examples - adjust column names based on your pipeline
SELECT 
    'IdentifyPrimaryObjects' as module, 
    ROUND(AVG(ExecutionTime_19IdentifyPrimaryObjects), 2) as avg_seconds,
    ROUND(MIN(ExecutionTime_19IdentifyPrimaryObjects), 2) as min_seconds,
    ROUND(MAX(ExecutionTime_19IdentifyPrimaryObjects), 2) as max_seconds
FROM execution_data
UNION ALL
SELECT 
    'MeasureObjectIntensity', 
    ROUND(AVG(ExecutionTime_41MeasureObjectIntensity), 2),
    ROUND(MIN(ExecutionTime_41MeasureObjectIntensity), 2),
    ROUND(MAX(ExecutionTime_41MeasureObjectIntensity), 2)
FROM execution_data
UNION ALL
SELECT 
    'MeasureObjectSizeShape', 
    ROUND(AVG(ExecutionTime_59MeasureObjectSizeShape), 2),
    ROUND(MIN(ExecutionTime_59MeasureObjectSizeShape), 2),
    ROUND(MAX(ExecutionTime_59MeasureObjectSizeShape), 2)
FROM execution_data;

-- 3. Processing gaps - find long delays between sites
WITH ordered_data AS (
    SELECT 
        site,
        wall_clock_time,
        wall_clock_time - LAG(wall_clock_time) OVER (ORDER BY wall_clock_time) as time_since_previous
    FROM execution_data
)
SELECT 
    site,
    wall_clock_time,
    EXTRACT(EPOCH FROM time_since_previous) as seconds_since_previous,
    ROUND(EXTRACT(EPOCH FROM time_since_previous) / 60.0, 2) as minutes_since_previous
FROM ordered_data
WHERE EXTRACT(EPOCH FROM time_since_previous) > 300  -- gaps > 5 minutes
ORDER BY seconds_since_previous DESC
LIMIT 10;

-- 4. List all ExecutionTime columns available
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'execution_data' 
  AND column_name LIKE 'ExecutionTime_%'
ORDER BY column_name;

-- 5. Processing timeline visualization data
WITH ordered_data AS (
    SELECT 
        site,
        wall_clock_time,
        ROW_NUMBER() OVER (ORDER BY wall_clock_time) as processing_order,
        wall_clock_time - LAG(wall_clock_time) OVER (ORDER BY wall_clock_time) as time_since_previous
    FROM execution_data
)
SELECT 
    processing_order,
    site,
    wall_clock_time,
    ROUND(EXTRACT(EPOCH FROM time_since_previous), 2) as gap_seconds
FROM ordered_data
ORDER BY processing_order
LIMIT 50;

-- 6. Dynamic total execution time calculation
-- This query shows how to sum all ExecutionTime columns dynamically
WITH exec_columns AS (
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_name = 'execution_data' 
      AND column_name LIKE 'ExecutionTime_%'
)
SELECT 
    'Use: SELECT ' || STRING_AGG(column_name, ' + ') || ' as total_execution_time FROM execution_data' as dynamic_sum_query
FROM exec_columns;

-- 7. Processing throughput by hour of day
SELECT 
    EXTRACT(HOUR FROM wall_clock_time) as hour_of_day,
    COUNT(*) as sites_processed
FROM execution_data
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 8. Find columns with highest average execution times
-- This approach is generic and doesn't rely on specific module names
WITH column_stats AS (
    SELECT 
        column_name,
        -- Get average of each ExecutionTime column using dynamic SQL would be ideal
        -- For now, use query #6 output to build a comprehensive analysis
        NULL as placeholder
    FROM information_schema.columns 
    WHERE table_name = 'execution_data' 
      AND column_name LIKE 'ExecutionTime_%'
)
SELECT 
    'Run query #6 to generate dynamic analysis of all ExecutionTime columns' as instruction;

-- 9. Daily processing summary
SELECT 
    date,
    COUNT(*) as sites_processed,
    MIN(wall_clock_time) as start_time,
    MAX(wall_clock_time) as end_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0, 2) as processing_hours
FROM execution_data
GROUP BY date
ORDER BY date;
