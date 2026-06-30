#!/usr/bin/env python3
"""
CFD Pipeline Post-Processor
Downloads simulation results from GCS, parses force coefficients,
and loads results into BigQuery.
"""

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import bigquery, storage


def download_results(bucket_name: str, case_name: str, local_dir: Path) -> Path:
    """Download simulation results from GCS to local directory."""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    prefix = f"{case_name}/"

    local_dir.mkdir(parents=True, exist_ok=True)

    blobs = list(bucket.list_blobs(prefix=prefix))
    if not blobs:
        raise FileNotFoundError(f"No results found in gs://{bucket_name}/{prefix}")

    for blob in blobs:
        relative_path = blob.name[len(prefix):]
        if not relative_path:
            continue
        local_path = local_dir / relative_path
        local_path.parent.mkdir(parents=True, exist_ok=True)
        blob.download_to_filename(str(local_path))
        print(f"  Downloaded: {relative_path}")

    return local_dir


def parse_force_coefficients(results_dir: Path) -> dict:
    """Parse OpenFOAM forceCoeffs output to extract Cl, Cd, Cm."""
    # Look for the forceCoeffs file in postProcessing directory
    force_dir = results_dir / "postProcessing" / "forceCoeffs"

    if not force_dir.exists():
        print(f"  Warning: No forceCoeffs directory found at {force_dir}")
        return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    # Find the latest time directory
    time_dirs = sorted(
        [d for d in force_dir.iterdir() if d.is_dir()],
        key=lambda d: float(d.name) if d.name.replace(".", "").isdigit() else 0,
    )

    if not time_dirs:
        print("  Warning: No time directories in forceCoeffs")
        return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    latest_dir = time_dirs[-1]
    coeff_file = latest_dir / "coefficient.dat"

    # Try alternate filename
    if not coeff_file.exists():
        coeff_file = latest_dir / "forceCoeffs.dat"

    if not coeff_file.exists():
        # Try any .dat file in the directory
        dat_files = list(latest_dir.glob("*.dat"))
        if dat_files:
            coeff_file = dat_files[0]
        else:
            print(f"  Warning: No .dat file found in {latest_dir}")
            return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    print(f"  Parsing: {coeff_file}")

    # Parse the coefficient file
    # Format: # Time Cd Cs Cl CmRoll CmPitch CmYaw Cd(f) Cd(r) Cs(f) Cs(r) Cl(f) Cl(r)
    lines = [
        line.strip()
        for line in coeff_file.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]

    if not lines:
        print("  Warning: No data lines in coefficient file")
        return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    # Get the last line (final iteration)
    last_line = lines[-1].split()
    iterations = len(lines)

    try:
        # Standard OpenFOAM forceCoeffs format:
        # Time Cd Cs Cl CmRoll CmPitch CmYaw ...
        cd = float(last_line[1])
        cl = float(last_line[3])
        cm = float(last_line[5])  # CmPitch
    except (IndexError, ValueError) as e:
        print(f"  Warning: Could not parse coefficients: {e}")
        return {"cl": None, "cd": None, "cm": None, "iterations": iterations, "converged": None}

    # Check convergence: compare last 10% of iterations
    converged = False
    if len(lines) > 100:
        recent_cl = []
        for line in lines[-50:]:
            try:
                recent_cl.append(float(line.split()[3]))
            except (IndexError, ValueError):
                pass
        if recent_cl:
            cl_range = max(recent_cl) - min(recent_cl)
            converged = cl_range < 0.001  # Converged if Cl variation < 0.001

    return {
        "cl": cl,
        "cd": cd,
        "cm": cm,
        "iterations": iterations,
        "converged": converged,
    }


def parse_metadata(results_dir: Path) -> dict:
    """Parse the metadata.json file uploaded by the entrypoint script."""
    metadata_file = results_dir / "metadata.json"
    if metadata_file.exists():
        return json.loads(metadata_file.read_text())
    return {}


def insert_to_bigquery(
    project_id: str,
    dataset_id: str,
    table_id: str,
    row: dict,
) -> None:
    """Insert a single row into BigQuery."""
    client = bigquery.Client(project=project_id)
    table_ref = f"{project_id}.{dataset_id}.{table_id}"

    errors = client.insert_rows_json(table_ref, [row])
    if errors:
        raise RuntimeError(f"BigQuery insert errors: {errors}")

    print(f"  Inserted row into {table_ref}")


def process_case(
    output_bucket: str,
    case_name: str,
    project_id: str,
    dataset_id: str = "cfd_results",
    table_id: str = "runs",
) -> dict:
    """Process a single simulation case end-to-end."""
    print(f"\n{'='*60}")
    print(f"Processing case: {case_name}")
    print(f"{'='*60}")

    # Download results
    local_dir = Path(f"/tmp/cfd_results/{case_name}")
    print("\n[1/4] Downloading results from GCS...")
    download_results(output_bucket, case_name, local_dir)

    # Parse metadata
    print("\n[2/4] Parsing metadata...")
    metadata = parse_metadata(local_dir)
    print(f"  Airfoil: {metadata.get('airfoil', 'unknown')}")
    print(f"  AoA: {metadata.get('aoa', 'unknown')}")
    print(f"  Wall time: {metadata.get('wall_time_seconds', 'unknown')}s")

    # Parse force coefficients
    print("\n[3/4] Parsing force coefficients...")
    coeffs = parse_force_coefficients(local_dir)
    print(f"  Cl = {coeffs['cl']}")
    print(f"  Cd = {coeffs['cd']}")
    print(f"  Cm = {coeffs['cm']}")
    print(f"  Iterations = {coeffs['iterations']}")
    print(f"  Converged = {coeffs['converged']}")

    # Build BigQuery row
    row = {
        "run_id": str(uuid.uuid4()),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "airfoil": metadata.get("airfoil", "unknown"),
        "case_name": case_name,
        "aoa": metadata.get("aoa", 0.0),
        "reynolds": metadata.get("reynolds", 0.0),
        "mach": metadata.get("mach", 0.0),
        "cl": coeffs["cl"],
        "cd": coeffs["cd"],
        "cm": coeffs["cm"],
        "iterations": coeffs["iterations"],
        "wall_time_seconds": metadata.get("wall_time_seconds"),
        "cost_usd": None,  # TODO: calculate from machine_type and wall_time
        "machine_type": metadata.get("machine_type", "unknown"),
        "converged": coeffs["converged"],
    }

    # Insert into BigQuery
    print("\n[4/4] Inserting into BigQuery...")
    insert_to_bigquery(project_id, dataset_id, table_id, row)

    print(f"\nCase {case_name} processed successfully")
    return row


def main():
    """Main entry point - process all cases or a specific case."""
    project_id = os.environ.get("PROJECT_ID")
    output_bucket = os.environ.get("GCS_OUTPUT_BUCKET")
    case_name = os.environ.get("CASE_NAME")

    if not project_id:
        print("ERROR: PROJECT_ID environment variable is required")
        sys.exit(1)
    if not output_bucket:
        print("ERROR: GCS_OUTPUT_BUCKET environment variable is required")
        sys.exit(1)

    if case_name:
        # Process a single case
        process_case(output_bucket, case_name, project_id)
    else:
        # Process all cases found in the output bucket
        print("No CASE_NAME specified, discovering cases in output bucket...")
        client = storage.Client()
        bucket = client.bucket(output_bucket)

        # List top-level "directories" in the bucket
        cases = set()
        for blob in bucket.list_blobs():
            parts = blob.name.split("/")
            if len(parts) > 1 and parts[0]:
                cases.add(parts[0])

        if not cases:
            print("No cases found in output bucket")
            sys.exit(1)

        print(f"Found {len(cases)} cases: {sorted(cases)}")

        results = []
        for case in sorted(cases):
            try:
                row = process_case(output_bucket, case, project_id)
                results.append(row)
            except Exception as e:
                print(f"\nError processing {case}: {e}")

        print(f"\n{'='*60}")
        print(f"Summary: {len(results)}/{len(cases)} cases processed successfully")
        print(f"{'='*60}")


if __name__ == "__main__":
    main()
