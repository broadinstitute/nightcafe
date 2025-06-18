# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a data analysis workspace for StarryNight image processing software output. It contains CellProfiler pipeline execution data for performance analysis and optimization.

**Primary Purpose**: Analyze execution times, performance bottlenecks, and processing results from optical pooled screening (OPS) image data processing pipelines.

## Data Structure

### Core Data
- `data/image_csv_files.tar.gz`: Archive containing 1,025 Image.csv files from CellProfiler analysis
- Each CSV contains ExecutionTime_* columns, image quality metrics, processing metadata, and algorithm results

### Data Extraction
```bash
# Extract data archive to gitignored folder
mkdir -p extracted_data
tar -xzf data/image_csv_files.tar.gz -C extracted_data
```

## Technology Stack

- **Language**: Python (inferred from comprehensive Python .gitignore patterns)
- **Focus**: Data analysis and performance optimization
- **Potential Libraries**: Likely pandas, numpy, matplotlib/seaborn for CSV analysis
- **Environment**: Supports modern Python tooling (ruff, poetry, pdm, uv)

## Development Notes

### Current State
- Repository is in early stages with minimal configuration
- No package dependencies defined (missing requirements.txt/pyproject.toml)
- Data-focused workspace rather than distributable package
- Supports Jupyter notebook development (.ipynb_checkpoints in gitignore)

### Key Analysis Areas
- ExecutionTime_* column analysis for module performance profiling
- Processing workflow optimization based on timing patterns
- Image quality metrics correlation with processing times
- Batch/plate/well/site metadata analysis

## StarryNight Context

StarryNight is a toolkit for optical pooled screening image data processing. Full documentation: https://broadinstitute.github.io/starrynight/

This workspace specifically focuses on analyzing the output and performance characteristics of StarryNight's CellProfiler integration.