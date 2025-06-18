#!/bin/bash
# Create DuckDB database with CellProfiler execution time data and wall clock timestamps

# Extract data if not already done
mkdir -p extracted_data
tar -xzf data/image_csv_files.tar.gz -C extracted_data

# Create DuckDB database
uv run duckdb execution_times.duckdb -c "
-- Load all CSV data
CREATE TABLE IF NOT EXISTS raw_execution_data AS 
SELECT * 
FROM read_csv_auto('extracted_data/*/Image.csv', filename=true)
WHERE ImageNumber = 1;

-- Load timestamp data
CREATE TABLE IF NOT EXISTS timestamps AS
SELECT 
    REGEXP_EXTRACT(filepath, '([^/]+)/Image\.csv$', 1) as dirname,
    CAST(birth_time AS BIGINT) as birth_timestamp,
    CAST(mod_time AS BIGINT) as mod_timestamp,
    CAST(change_time AS BIGINT) as change_timestamp,
    to_timestamp(CAST(mod_time AS BIGINT)) as wall_clock_time
FROM read_csv_auto('data/file_timestamps_raw.csv', 
    columns={'filepath': 'VARCHAR', 'birth_time': 'VARCHAR', 'mod_time': 'VARCHAR', 'change_time': 'VARCHAR'},
    header=false
);

-- Create main analysis table with parsed metadata, execution times, and timestamps
DROP TABLE IF EXISTS execution_data;
CREATE TABLE execution_data AS 
SELECT 
    -- Parse metadata from directory path
    SPLIT_PART(SPLIT_PART(raw.filename, '/', -2), '-', 1) as date,
    SPLIT_PART(SPLIT_PART(raw.filename, '/', -2), '-', 2) || '-' || SPLIT_PART(SPLIT_PART(raw.filename, '/', -2), '-', 3) as batch,
    SPLIT_PART(SPLIT_PART(raw.filename, '/', -2), '-', 4) as plate,
    SPLIT_PART(SPLIT_PART(raw.filename, '/', -2), '-', 5) as well,
    CAST(SPLIT_PART(SPLIT_PART(raw.filename, '/', -2), '-', 6) AS INTEGER) as site,
    SPLIT_PART(raw.filename, '/', -2) as dirname,
    
    -- Timestamp data
    ts.wall_clock_time,
    ts.mod_timestamp as wall_clock_timestamp,
    
    -- Include all ExecutionTime columns
    COLUMNS('ExecutionTime_.*')
    
FROM raw_execution_data raw
LEFT JOIN timestamps ts ON SPLIT_PART(raw.filename, '/', -2) = ts.dirname;

-- Create summary statistics table with calculated total execution time
DROP TABLE IF EXISTS execution_summary;
CREATE TABLE execution_summary AS
WITH ordered_data AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY wall_clock_time) as processing_order,
        wall_clock_time - LAG(wall_clock_time) OVER (ORDER BY wall_clock_time) as time_since_previous,
        -- Calculate sum of all ExecutionTime columns
        (
            ExecutionTime_01LoadData + ExecutionTime_02MeasureImageIntensity + ExecutionTime_03FlagImage +
            ExecutionTime_04Align + ExecutionTime_05Threshold + ExecutionTime_06Threshold +
            ExecutionTime_07ImageMath + ExecutionTime_08ImageMath + ExecutionTime_09MaskImage +
            ExecutionTime_10MaskImage + ExecutionTime_11MaskImage + ExecutionTime_12MaskImage +
            ExecutionTime_13MeasureColocalization + ExecutionTime_14FlagImage + ExecutionTime_15ImageMath +
            ExecutionTime_16Morph + ExecutionTime_17MeasureImageIntensity + ExecutionTime_18ImageMath +
            ExecutionTime_19IdentifyPrimaryObjects + ExecutionTime_20MeasureImageAreaOccupied
            -- Note: This is a subset - add more ExecutionTime columns as needed
        ) as total_execution_time
    FROM execution_data
)
SELECT 
    date,
    batch,
    plate,
    well,
    site,
    dirname,
    wall_clock_time,
    total_execution_time,
    processing_order,
    EXTRACT(EPOCH FROM time_since_previous) as seconds_since_previous,
    -- Add key individual execution times
    ExecutionTime_01LoadData,
    ExecutionTime_02MeasureImageIntensity,
    ExecutionTime_04Align,
    ExecutionTime_19IdentifyPrimaryObjects
FROM ordered_data;

-- Clean up temporary tables
DROP TABLE raw_execution_data;

-- Show summary
SELECT 
    COUNT(*) as total_records,
    MIN(wall_clock_time) as first_processed,
    MAX(wall_clock_time) as last_processed,
    EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0 as total_hours,
    ROUND(AVG(total_execution_time), 2) as avg_execution_seconds,
    ROUND(COUNT(*) / (EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0), 2) as sites_per_hour
FROM execution_summary;
"

echo "Database created: execution_times.duckdb"
echo "Main tables: execution_data (full data), execution_summary (analysis-ready)"