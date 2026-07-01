#!/usr/bin/env python3
"""Upload CFD results CSV to BigQuery."""

import os
import sys

from google.cloud import bigquery


def main() -> int:
    project_id = os.environ.get("GCP_PROJECT_ID")
    if not project_id:
        print("Error: GCP_PROJECT_ID environment variable is not set.")
        return 1

    csv_path = os.environ.get("CSV_PATH", "data/results.csv")
    if not os.path.isfile(csv_path):
        print(f"Error: CSV file not found: {csv_path}")
        return 1

    dataset_id = "cfd_results"
    table_id = "coefficients"
    table_ref = f"{project_id}.{dataset_id}.{table_id}"

    client = bigquery.Client(project=project_id)
    client.create_dataset(f"{project_id}.{dataset_id}", exists_ok=True)

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        schema=[
            bigquery.SchemaField("case_name", "STRING"),
            bigquery.SchemaField("airfoil", "STRING"),
            bigquery.SchemaField("aoa", "FLOAT"),
            bigquery.SchemaField("reynolds", "FLOAT"),
            bigquery.SchemaField("mach", "FLOAT"),
            bigquery.SchemaField("cl", "FLOAT"),
            bigquery.SchemaField("cd", "FLOAT"),
            bigquery.SchemaField("cm", "FLOAT"),
            bigquery.SchemaField("iterations", "INTEGER"),
            bigquery.SchemaField("wall_time_seconds", "INTEGER"),
            bigquery.SchemaField("converged", "BOOLEAN"),
            bigquery.SchemaField("timestamp", "TIMESTAMP"),
            bigquery.SchemaField("machine_type", "STRING"),
        ],
    )

    with open(csv_path, "rb") as source_file:
        load_job = client.load_table_from_file(source_file, table_ref, job_config=job_config)
    load_job.result()

    table = client.get_table(table_ref)
    print(f"Loaded {table.num_rows} rows into {table.project}.{table.dataset_id}.{table.table_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
