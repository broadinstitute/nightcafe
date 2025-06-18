-- Example queries for the execution times database

-- 1. Overall processing statistics
SELECT 
    COUNT(*) as total_sites,
    MIN(wall_clock_time) as start_time,
    MAX(wall_clock_time) as end_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0, 2) as total_hours,
    ROUND(AVG(total_execution_time), 2) as avg_execution_seconds,
    ROUND(COUNT(*) / (EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0), 2) as sites_per_hour
FROM execution_summary;

-- 2. Top slowest modules by average execution time
SELECT 
    'LoadData' as module, ROUND(AVG(ExecutionTime_01LoadData), 2) as avg_seconds
FROM execution_data
UNION ALL
SELECT 'Align', ROUND(AVG(ExecutionTime_04Align), 2)
FROM execution_data
UNION ALL
SELECT 'IdentifyPrimaryObjects', ROUND(AVG(ExecutionTime_19IdentifyPrimaryObjects), 2)
FROM execution_data
ORDER BY avg_seconds DESC;

-- 3. Processing gaps - find long delays between sites
SELECT 
    site,
    wall_clock_time,
    seconds_since_previous,
    ROUND(seconds_since_previous / 60.0, 2) as minutes_since_previous
FROM execution_summary
WHERE seconds_since_previous > 300  -- gaps > 5 minutes
ORDER BY seconds_since_previous DESC
LIMIT 10;

-- 4. Execution time vs wall clock time efficiency
WITH efficiency AS (
    SELECT 
        site,
        total_execution_time,
        seconds_since_previous as wall_clock_duration,
        CASE 
            WHEN seconds_since_previous > 0 
            THEN ROUND(total_execution_time / seconds_since_previous * 100, 2)
            ELSE NULL
        END as efficiency_percent
    FROM execution_summary
    WHERE seconds_since_previous IS NOT NULL
)
SELECT 
    ROUND(AVG(efficiency_percent), 2) as avg_efficiency_percent,
    MIN(efficiency_percent) as min_efficiency_percent,
    MAX(efficiency_percent) as max_efficiency_percent
FROM efficiency
WHERE efficiency_percent < 200;  -- exclude outliers

-- 5. Processing timeline visualization data
SELECT 
    processing_order,
    site,
    wall_clock_time,
    total_execution_time,
    ExecutionTime_04Align as align_time,
    ROUND(seconds_since_previous, 2) as gap_seconds
FROM execution_summary
ORDER BY processing_order
LIMIT 50;