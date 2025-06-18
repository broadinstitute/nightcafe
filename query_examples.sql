-- Analysis queries for execution time database

-- 1. PROCESSING TIMELINE - Shows each image in chronological order with timing
WITH timeline AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY wall_clock_time) as sequence_number,
        site,
        dirname,
        wall_clock_time,
        LAG(wall_clock_time) OVER (ORDER BY wall_clock_time) as previous_time,
        EXTRACT(EPOCH FROM wall_clock_time - LAG(wall_clock_time) OVER (ORDER BY wall_clock_time)) as seconds_since_previous
    FROM execution_data
)
SELECT 
    sequence_number,
    site,
    dirname,
    wall_clock_time,
    ROUND(seconds_since_previous, 2) as seconds_since_previous,
    ROUND(seconds_since_previous / 60.0, 2) as minutes_since_previous,
    ROUND(sequence_number / (EXTRACT(EPOCH FROM wall_clock_time - FIRST_VALUE(wall_clock_time) OVER (ORDER BY wall_clock_time)) / 3600.0), 2) as running_images_per_hour
FROM timeline
ORDER BY sequence_number;

-- 2. THROUGHPUT OVER TIME - Performance statistics in time buckets
WITH time_buckets AS (
    SELECT 
        site,
        wall_clock_time,
        NTILE(20) OVER (ORDER BY wall_clock_time) as time_bucket_20,  -- 20 5% buckets
        EXTRACT(HOUR FROM wall_clock_time) as hour_of_day
    FROM execution_data
),
bucket_stats AS (
    SELECT 
        time_bucket_20 as bucket_number,
        COUNT(*) as images_in_bucket,
        MIN(wall_clock_time) as bucket_start_time,
        MAX(wall_clock_time) as bucket_end_time,
        EXTRACT(EPOCH FROM MAX(wall_clock_time) - MIN(wall_clock_time)) / 60.0 as bucket_duration_minutes
    FROM time_buckets
    GROUP BY time_bucket_20
)
SELECT 
    bucket_number,
    images_in_bucket,
    bucket_start_time,
    bucket_end_time,
    ROUND(bucket_duration_minutes, 2) as duration_minutes,
    ROUND(images_in_bucket / (bucket_duration_minutes / 60.0), 2) as images_per_hour
FROM bucket_stats
WHERE bucket_duration_minutes > 0
ORDER BY bucket_number;

-- 3. PROCESSING BOTTLENECKS - Identify unusual delays between images
WITH gaps AS (
    SELECT 
        site,
        dirname,
        wall_clock_time,
        LAG(wall_clock_time) OVER (ORDER BY wall_clock_time) as previous_time,
        EXTRACT(EPOCH FROM wall_clock_time - LAG(wall_clock_time) OVER (ORDER BY wall_clock_time)) as gap_seconds
    FROM execution_data
),
gap_stats AS (
    SELECT 
        AVG(gap_seconds) as avg_gap,
        STDDEV(gap_seconds) as stddev_gap,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY gap_seconds) as p95_gap
    FROM gaps
    WHERE gap_seconds > 0
)
SELECT 
    g.site,
    g.dirname,
    g.wall_clock_time,
    g.previous_time,
    ROUND(g.gap_seconds, 2) as gap_seconds,
    ROUND(g.gap_seconds / 60.0, 2) as gap_minutes,
    ROUND(g.gap_seconds / s.avg_gap, 2) as times_average_gap,
    CASE 
        WHEN g.gap_seconds > s.p95_gap THEN 'BOTTLENECK'
        WHEN g.gap_seconds > s.avg_gap + 2 * s.stddev_gap THEN 'SLOW'
        ELSE 'NORMAL'
    END as status
FROM gaps g, gap_stats s
WHERE g.gap_seconds > 0
ORDER BY g.gap_seconds DESC;

-- 4. OVERALL STATISTICS - Summary of the entire run
WITH time_gaps AS (
    SELECT 
        wall_clock_time,
        EXTRACT(EPOCH FROM wall_clock_time - LAG(wall_clock_time) OVER (ORDER BY wall_clock_time)) as gap_seconds
    FROM execution_data
)
SELECT 
    COUNT(*) as total_images,
    MIN(wall_clock_time) as start_time,
    MAX(wall_clock_time) as end_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0, 2) as total_hours,
    ROUND(COUNT(*) / (EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0), 2) as avg_images_per_hour,
    ROUND((SELECT AVG(gap_seconds) FROM time_gaps WHERE gap_seconds IS NOT NULL), 2) as avg_seconds_between_images
FROM execution_data;

-- 5. HOURLY THROUGHPUT - How many images processed each hour
SELECT 
    EXTRACT(HOUR FROM wall_clock_time) as hour_of_day,
    COUNT(*) as images_processed,
    MIN(wall_clock_time) as hour_start,
    MAX(wall_clock_time) as hour_end,
    ROUND(COUNT(*) / (EXTRACT(EPOCH FROM MAX(wall_clock_time) - MIN(wall_clock_time)) / 3600.0), 2) as images_per_hour
FROM execution_data
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 6. MODULE DISCOVERY - List all ExecutionTime columns to see what modules were run
SELECT 
    column_name,
    REPLACE(column_name, 'ExecutionTime_', '') as module_name
FROM information_schema.columns 
WHERE table_name = 'execution_data' 
  AND column_name LIKE 'ExecutionTime_%'
ORDER BY column_name;

-- 7. GENERATE TOTAL EXECUTION TIME QUERY - Creates SQL to sum all ExecutionTime columns
WITH exec_columns AS (
    SELECT column_name 
    FROM information_schema.columns 
    WHERE table_name = 'execution_data' 
      AND column_name LIKE 'ExecutionTime_%'
)
SELECT 
    'SELECT site, dirname, wall_clock_time, ' || 
    STRING_AGG(column_name, ' + ') || 
    ' as total_execution_seconds FROM execution_data ORDER BY total_execution_seconds DESC LIMIT 50;' as query_to_run
FROM exec_columns;
