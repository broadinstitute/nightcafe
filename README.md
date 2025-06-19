# StarryNight Output Analysis

This repository contains output data from the StarryNight image processing software for analysis and exploration of processing performance and results.

## About StarryNight

StarryNight is a toolkit for processing, analyzing, and managing optical pooled screening (OPS) image data. For detailed documentation, see [https://broadinstitute.github.io/starrynight/](https://broadinstitute.github.io/starrynight/).

## Purpose

StarryNight generates comprehensive output data from CellProfiler image processing pipelines. This workspace is used to:

- **Analyze execution times and performance characteristics** of image processing modules
- **Identify performance bottlenecks** in processing pipelines through ExecutionTime_* metrics
- **Explore timing patterns** across different processing stages, samples, and experimental conditions

## Data

### Image.csv Archive
Archive of 1,025 Image.csv files from CellProfiler analysis containing timing data and extensive image analysis metrics.

Each CSV file contains:
- **ExecutionTime_\* columns**: Processing time for individual CellProfiler modules
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

Creates a DuckDB database (`data/execution_times.duckdb`) containing:
- All raw data from Image.csv files (including all ExecutionTime_* columns)
- Wall clock timestamps from the processing server
- Parsed metadata (batch, plate, well, site)
- Single table structure for flexible analysis

The script also exports key tables to CSV files in `exported_tables/`.

### Running Queries

Run the example queries:
```bash
uv run duckdb data/execution_times.duckdb < query_examples.sql
```

Or run queries interactively:
```bash
uv run duckdb data/execution_times.duckdb
```

See `query_examples.sql` for various analysis queries including:
- Overall processing statistics and throughput
- Module performance comparisons
- Processing timeline and gap analysis
- Dynamic column discovery
- Hourly and daily summaries

### Interactive Analysis

For interactive data exploration:
- **Marimo notebook**: Run `uv run marimo edit explore_execution_times.py` for reactive visualizations with Altair
- **Create new notebooks**: Use `uv run marimo new` to create additional reactive notebooks

### Direct Web Access

You can read the data directly from GitHub without downloading:

```python
import duckdb

conn = duckdb.connect()
conn.execute("INSTALL httpfs; LOAD httpfs;")

# Read directly from GitHub
df = conn.execute("""
    SELECT * FROM 'https://raw.githubusercontent.com/broadinstitute/nightcafe/main/data/execution_data.parquet'
""").df()
```
