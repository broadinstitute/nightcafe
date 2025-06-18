# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a data analysis workspace for StarryNight image processing software output. It contains CellProfiler pipeline execution data for performance analysis and optimization.

**Primary Purpose**: Analyze execution times, performance bottlenecks, and processing results from optical pooled screening (OPS) image data processing pipelines.

## Data Structure

### Core Data
- `data/image_csv_files.tar.gz`: Archive containing 1,025 Image.csv files from CellProfiler analysis
- `data/file_timestamps_raw.csv`: Wall clock timestamps for server processing times
- `execution_times.duckdb`: Processed DuckDB database ready for analysis
- Each CSV contains ExecutionTime_* columns, image quality metrics, processing metadata, and algorithm results

### Data Extraction
```bash
# Extract data archive to gitignored folder
mkdir -p extracted_data
tar -xzf data/image_csv_files.tar.gz -C extracted_data
```

## Technology Stack

- **Language**: Python 3.11+
- **Focus**: Data analysis and performance optimization
- **Core Libraries**: 
  - DuckDB (v1.3.1+) - Primary database for performance analysis
  - Pandas (v2.3.0+) - Data manipulation
  - Matplotlib/Seaborn - Visualization
  - Marimo (v0.14.0+) - Interactive notebooks
  - PyGWalker (v0.4.9.15+) - Exploratory data analysis
- **Environment**: Uses uv for package management and virtual environments

## Development Notes

### Current State
- Active data analysis workspace with DuckDB-based performance analytics
- Dependencies managed via pyproject.toml and uv package manager
- Main database: `execution_times.duckdb` containing processed CellProfiler timing data
- Extracted data directory contains 1,025 CSV files with execution metrics
- Supports both command-line analysis (DuckDB SQL) and interactive notebooks (Marimo)

### Key Analysis Areas
- ExecutionTime_* column analysis for module performance profiling
- Processing workflow optimization based on timing patterns
- Image quality metrics correlation with processing times
- Batch/plate/well/site metadata analysis

## Key Files

- `create_execution_db.sh`: Bash script to create/refresh the DuckDB database from raw CSV data
- `query_examples.sql`: Collection of analysis queries for performance profiling
- `pyproject.toml`: Python project configuration with analysis dependencies
- `README.md`: User-facing documentation and usage instructions

## Analysis Workflow

1. Extract data archive if needed: `tar -xzf data/image_csv_files.tar.gz -C extracted_data`
2. Create/refresh database: `./create_execution_db.sh`
3. Run example queries: `uv run duckdb execution_times.duckdb < query_examples.sql`
4. Interactive analysis: `uv run duckdb execution_times.duckdb` or use Marimo notebooks

## StarryNight Context

StarryNight is a toolkit for optical pooled screening image data processing. Full documentation: https://broadinstitute.github.io/starrynight/

This workspace specifically focuses on analyzing the output and performance characteristics of StarryNight's CellProfiler integration.