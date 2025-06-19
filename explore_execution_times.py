import marimo

__generated_with = "0.14.0"
app = marimo.App(width="medium")


@app.cell
def _():
    import altair as alt
    import duckdb
    import marimo as mo

    # Enable Altair data transformers for large datasets
    alt.data_transformers.enable("default", max_rows=None)
    return alt, duckdb, mo


@app.cell
def _(duckdb):
    from pathlib import Path

    # Create in-memory DuckDB connection
    conn = duckdb.connect()

    # Check if local file exists, otherwise use GitHub URL
    local_path = "data/execution_data.parquet"
    github_url = "https://raw.githubusercontent.com/broadinstitute/nightcafe/refs/heads/main/data/execution_data.parquet"

    if Path(local_path).exists():
        data_source = local_path
        print(f"Loading data from local file: {local_path}")
    else:
        # Install and load httpfs extension for web access
        conn.execute("INSTALL httpfs; LOAD httpfs;")
        data_source = github_url
        print(f"Loading data from GitHub: {github_url}")

    # Load data from Parquet file
    df = conn.execute(f"""
        SELECT * FROM '{data_source}'
    """).df()

    # Get all ExecutionTime columns
    exec_cols = [col for col in df.columns if col.startswith("ExecutionTime_")]

    # Build sum expression
    sum_expr = " + ".join([f'COALESCE("{col}", 0)' for col in exec_cols])

    # Add calculated fields
    df = conn.execute(f"""
        SELECT
            *,
            {sum_expr} as total_execution_time,
            wall_clock_timestamp - MIN(wall_clock_timestamp) OVER () as seconds_from_start
        FROM df
        ORDER BY wall_clock_time
    """).df()

    print(
        f"Loaded {len(df)} images with {len(exec_cols)} execution time columns"
    )
    return (df,)


@app.cell
def _(df, mo):
    # Display overview statistics
    stats = f"""
    # Execution Time Analysis

    ## Dataset Overview
    - **Total Images**: {len(df):,}
    - **Processing Duration**: {df["seconds_from_start"].max():.1f} seconds
    - **Average Execution Time**: {df["total_execution_time"].mean():.1f} seconds
    - **Median Execution Time**: {df["total_execution_time"].median():.1f} seconds
    - **Min/Max**: {df["total_execution_time"].min():.1f} / {df["total_execution_time"].max():.1f} seconds
    """

    mo.md(stats)
    return


@app.cell
def _(df, mo):
    # Interactive table preview
    mo.md("### Data Preview")
    table_df = df[
        [
            "dirname",
            "batch",
            "plate",
            "well",
            "site",
            "total_execution_time",
            "seconds_from_start",
        ]
    ]

    return (table_df,)


@app.cell
def _(mo, table_df):
    mo.ui.table(table_df, selection=None)
    return


@app.cell
def _(alt, df, mo):
    # Timeline visualization
    mo.md("## Processing Timeline")

    # Create interactive scatter plot with selection
    timeline_brush = alt.selection_interval()

    timeline = (
        alt.Chart(df)
        .mark_circle(size=50, opacity=0.5)
        .encode(
            x=alt.X("seconds_from_start:Q", title="Seconds from Start"),
            y=alt.Y(
                "total_execution_time:Q", title="Total Execution Time (seconds)"
            ),
            color=alt.condition(
                timeline_brush,
                alt.Color("batch:N", title="Batch"),
                alt.value("lightgray"),
            ),
            tooltip=[
                "dirname",
                "batch",
                "plate",
                "well",
                "site",
                "total_execution_time",
                "seconds_from_start",
            ],
        )
        .add_params(timeline_brush)
        .properties(
            width=700, height=400, title="Execution Time Over Processing Run"
        )
    )

    return (timeline,)


@app.cell
def _(timeline):
    timeline
    return


@app.cell
def _(df):
    # Define the line from (0, 400) to (2400, 2800)
    # Line equation: y = mx + b where m = (2800-400)/(2400-0) = 1, b = 400
    # So the line is: y = x + 400

    # Create subset of points above the line
    outliers_df = df[
        df["total_execution_time"] > df["seconds_from_start"] + 400
    ].copy()

    print(f"Found {len(outliers_df)} outlier points above the line y = x + 400")
    print(f"That's {len(outliers_df) / len(df) * 100:.1f}% of all points")

    return (outliers_df,)


@app.cell
def _(outliers_df):
    # Check if total_execution_time = seconds_from_start + constant for outliers
    outliers_df["time_difference"] = (
        outliers_df["total_execution_time"] - outliers_df["seconds_from_start"]
    )

    print(
        "Analysis of relationship: total_execution_time = seconds_from_start + constant"
    )
    print(f"Mean difference: {outliers_df['time_difference'].mean():.2f}")
    print(f"Std deviation: {outliers_df['time_difference'].std():.2f}")
    print(f"Min difference: {outliers_df['time_difference'].min():.2f}")
    print(f"Max difference: {outliers_df['time_difference'].max():.2f}")
    print(
        f"Range: {outliers_df['time_difference'].max() - outliers_df['time_difference'].min():.2f}"
    )

    # Check how many are within a small range
    const_threshold = 50  # seconds
    mean_diff = outliers_df["time_difference"].mean()
    within_threshold = outliers_df[
        (outliers_df["time_difference"] > mean_diff - const_threshold)
        & (outliers_df["time_difference"] < mean_diff + const_threshold)
    ]

    print(
        f"\n{len(within_threshold)} out of {len(outliers_df)} outliers ({len(within_threshold) / len(outliers_df) * 100:.1f}%) have difference within ±{const_threshold}s of mean"
    )

    return (within_threshold,)


@app.cell
def _(within_threshold):
    within_threshold
    return


@app.cell
def _(alt, within_threshold):
    timeline2 = (
        alt.Chart(within_threshold)
        .mark_circle(size=50, opacity=0.5)
        .encode(
            x=alt.X("seconds_from_start:Q"), y=alt.Y("total_execution_time:Q")
        )
    )
    timeline2
    return


@app.cell
def _(within_threshold):
    within_threshold
    return


if __name__ == "__main__":
    app.run()
