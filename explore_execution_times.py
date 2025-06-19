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
    # Connect to DuckDB and load data (read-only to avoid lock conflicts)
    conn = duckdb.connect("execution_times.duckdb", read_only=True)

    # Get all ExecutionTime columns
    exec_cols_query = conn.execute("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'execution_data'
        AND column_name LIKE 'ExecutionTime_%'
        ORDER BY column_name
    """).fetchall()

    exec_cols = [col[0] for col in exec_cols_query]

    # Build sum expression
    sum_expr = " + ".join([f'COALESCE("{col}", 0)' for col in exec_cols])

    # Load data with calculated fields
    df = conn.execute(f"""
        SELECT
            *,
            {sum_expr} as total_execution_time,
            EXTRACT(EPOCH FROM (wall_clock_time - MIN(wall_clock_time) OVER ())) / 60.0 as minutes_from_start
        FROM execution_data
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
    - **Processing Duration**: {df["minutes_from_start"].max():.1f} minutes
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
            "minutes_from_start",
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
            x=alt.X("minutes_from_start:Q", title="Minutes from Start"),
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
                "minutes_from_start",
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


if __name__ == "__main__":
    app.run()
