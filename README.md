# StarryNight Output Analysis

This repository contains output data from the StarryNight image processing software for analysis and exploration of processing performance and results.

## About StarryNight

StarryNight is a toolkit for processing, analyzing, and managing optical pooled screening (OPS) image data. For detailed documentation, see [https://broadinstitute.github.io/starrynight/](https://broadinstitute.github.io/starrynight/).

## Purpose

StarryNight generates comprehensive output data from CellProfiler image processing pipelines. This workspace is used to:

- **Analyze execution times and performance characteristics** of image processing modules
- **Identify performance bottlenecks** in processing pipelines through ExecutionTime_* metrics
- **Explore timing patterns** across different processing stages, samples, and experimental conditions
- **Optimize processing workflows** based on data-driven insights from real execution data
- **Investigate processing results and quality metrics** from comprehensive image analysis

## Data

### Image.csv Archive
Archive of 1,025 Image.csv files from CellProfiler analysis containing timing data and extensive image analysis metrics.

Each CSV file contains:
- **ExecutionTime_* columns**: Processing time for individual CellProfiler modules
- **Image quality metrics**: Focus scores, intensity measurements, correlation data
- **Processing metadata**: Batch, plate, well, site information
- **Algorithm results**: Object counts, measurements, and derived metrics

**Extract:**
```bash
# Extract to a gitignored folder
mkdir -p extracted_data
tar -xzf data/image_csv_files.tar.gz -C extracted_data
```

**Created with:**
```bash
find . -name "Image.csv" -type f | tar -czf ~/image_csv_files.tar.gz -T -
```

### File Timestamps
Wall clock timestamps for when each Image.csv file was created on the processing server.

**Format:** `filepath,birth_time,mod_time,change_time` (Unix timestamps)

**Created with:**
```bash
find -name "Image.csv" -exec stat -c "%n,%W,%Y,%Z" {} \; > ~/nightcafe/file_timestamps_raw.csv
```

## Analysis

### Create Database
```bash
./create_execution_db.sh
```

Creates a DuckDB database (`execution_times.duckdb`) that combines:
- Execution time data from all ExecutionTime_* columns
- Wall clock timestamps from the processing server
- Parsed metadata (batch, plate, well, site)

### Example Queries
```sql
-- Processing timeline
SELECT site, wall_clock_time, total_execution_time, seconds_since_previous
FROM execution_summary
ORDER BY processing_order;

-- Module performance comparison
SELECT 'Align' as module, AVG(ExecutionTime_04Align) as avg_seconds
FROM execution_data;

-- Throughput analysis
SELECT COUNT(*) / (EXTRACT(EPOCH FROM (MAX(wall_clock_time) - MIN(wall_clock_time))) / 3600.0) as sites_per_hour
FROM execution_summary;
```

See `query_examples.sql` for more analysis queries.