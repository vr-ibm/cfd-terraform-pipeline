#!/usr/bin/env bash
set -euo pipefail

CSV_PATH="${1:-data/results.csv}"

if [ -z "${GCP_PROJECT_ID:-}" ]; then
    echo "Error: GCP_PROJECT_ID environment variable is not set."
    exit 1
fi

if [ ! -f "${CSV_PATH}" ]; then
    echo "Error: CSV file not found: ${CSV_PATH}"
    exit 1
fi

DATASET="cfd_results"
TABLE="coefficients"
SCHEMA="case_name:STRING,airfoil:STRING,aoa:FLOAT,reynolds:FLOAT,mach:FLOAT,cl:FLOAT,cd:FLOAT,cm:FLOAT,iterations:INTEGER,wall_time_seconds:INTEGER,converged:BOOLEAN,timestamp:TIMESTAMP,machine_type:STRING"

bq --project_id="${GCP_PROJECT_ID}" mk --dataset --exists "${GCP_PROJECT_ID}:${DATASET}"

bq --project_id="${GCP_PROJECT_ID}" load \
    --source_format=CSV \
    --skip_leading_rows=1 \
    --write_disposition=WRITE_TRUNCATE \
    "${GCP_PROJECT_ID}:${DATASET}.${TABLE}" \
    "${CSV_PATH}" \
    "${SCHEMA}"

echo "Upload complete!"
echo "SELECT airfoil, aoa, cl, cd FROM cfd_results.coefficients ORDER BY airfoil, aoa"
