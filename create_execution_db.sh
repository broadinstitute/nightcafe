#!/bin/bash
# Create DuckDB database with CellProfiler execution time data and wall clock timestamps
set -euo pipefail

# Check if required files exist
if [ ! -f "data/image_csv_files.tar.gz" ]; then
    echo "Error: data/image_csv_files.tar.gz not found"
    exit 1
fi

if [ ! -f "data/file_timestamps_raw.csv" ]; then
    echo "Error: data/file_timestamps_raw.csv not found"
    exit 1
fi

# Extract data if not already done
mkdir -p extracted_data
echo "Extracting CSV files..."
tar -xzf data/image_csv_files.tar.gz -C extracted_data

# Create DuckDB database
echo "Creating DuckDB database..."
uv run duckdb execution_times.duckdb -c "
-- Load all CSV data
DROP TABLE IF EXISTS raw_execution_data;
CREATE TABLE raw_execution_data AS 
SELECT * 
FROM read_csv_auto('extracted_data/*/Image.csv', filename=true)
WHERE ImageNumber = 1;

-- Load timestamp data
DROP TABLE IF EXISTS timestamps;
CREATE TABLE timestamps AS
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

-- Create main analysis table with parsed metadata and timestamps
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
    
    -- Include all columns from raw data
    raw.*
    
FROM raw_execution_data raw
LEFT JOIN timestamps ts ON SPLIT_PART(raw.filename, '/', -2) = ts.dirname;

-- Show summary
SELECT 
    COUNT(*) as total_records,
    MIN(wall_clock_time) as first_processed,
    MAX(wall_clock_time) as last_processed,
    ROUND(EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0, 2) as total_hours
FROM execution_data;
"

echo "Database created: execution_times.duckdb"
echo "Main tables: execution_data (full data with all columns)"