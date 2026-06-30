#!/usr/bin/env python3
"""
Local CFD Post-Processor
Parses OpenFOAM results from local output directory and writes to CSV.
"""

import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path


def parse_force_coefficients(results_dir: Path) -> dict:
    """Parse OpenFOAM forceCoeffs output to extract Cl, Cd, Cm."""
    force_dir = results_dir / "postProcessing" / "forceCoeffs"

    if not force_dir.exists():
        return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    time_dirs = sorted(
        [d for d in force_dir.iterdir() if d.is_dir()],
        key=lambda d: float(d.name) if d.name.replace(".", "").isdigit() else 0,
    )

    if not time_dirs:
        return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    latest_dir = time_dirs[-1]

    # Find the data file
    coeff_file = None
    for name in ["coefficient.dat", "forceCoeffs.dat"]:
        candidate = latest_dir / name
        if candidate.exists():
            coeff_file = candidate
            break
    if not coeff_file:
        dat_files = list(latest_dir.glob("*.dat"))
        coeff_file = dat_files[0] if dat_files else None

    if not coeff_file:
        return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    lines = [
        line.strip()
        for line in coeff_file.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]

    if not lines:
        return {"cl": None, "cd": None, "cm": None, "iterations": None, "converged": None}

    last_line = lines[-1].split()
    iterations = len(lines)

    try:
        cd = float(last_line[1])
        cl = float(last_line[3])
        cm = float(last_line[5])
    except (IndexError, ValueError):
        return {"cl": None, "cd": None, "cm": None, "iterations": iterations, "converged": None}

    # Check convergence
    converged = False
    if len(lines) > 100:
        recent_cl = []
        for line in lines[-50:]:
            try:
                recent_cl.append(float(line.split()[3]))
            except (IndexError, ValueError):
                pass
        if recent_cl:
            converged = (max(recent_cl) - min(recent_cl)) < 0.001

    return {"cl": cl, "cd": cd, "cm": cm, "iterations": iterations, "converged": converged}


def _csv_value(value):
    """Convert None to empty string while preserving 0/0.0 values."""
    return "" if value is None else value


def process_all_cases(output_dir: Path, results_csv: Path) -> None:
    """Process all case directories and append results to CSV."""
    if not output_dir.exists():
        print(f"Output directory does not exist: {output_dir}")
        return

    cases = sorted([d for d in output_dir.iterdir() if d.is_dir()])

    if not cases:
        print("No cases found in output directory")
        return

    # Check if CSV needs header
    write_header = not results_csv.exists() or results_csv.stat().st_size == 0

    results_csv.parent.mkdir(parents=True, exist_ok=True)

    with results_csv.open("a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow([
                "case_name", "airfoil", "aoa", "reynolds", "mach",
                "cl", "cd", "cm", "iterations", "wall_time_seconds",
                "converged", "timestamp",
            ])

        for case_dir in cases:
            case_name = case_dir.name
            print(f"  Processing: {case_name}")

            # Parse metadata
            metadata_file = case_dir / "metadata.json"
            if metadata_file.exists():
                metadata = json.loads(metadata_file.read_text())
            else:
                print(f"    Warning: No metadata.json for {case_name}")
                metadata = {}

            # Parse force coefficients
            coeffs = parse_force_coefficients(case_dir)

            writer.writerow([
                case_name,
                metadata.get("airfoil", "unknown"),
                _csv_value(metadata.get("aoa")),
                _csv_value(metadata.get("reynolds")),
                _csv_value(metadata.get("mach")),
                _csv_value(coeffs["cl"]),
                _csv_value(coeffs["cd"]),
                _csv_value(coeffs["cm"]),
                _csv_value(coeffs["iterations"]),
                _csv_value(metadata.get("wall_time_seconds")),
                _csv_value(coeffs["converged"]),
                metadata.get("timestamp", datetime.now(timezone.utc).isoformat()),
            ])

            print(f"    Cl={coeffs['cl']}, Cd={coeffs['cd']}, Cm={coeffs['cm']}")

    print(f"\n  Results written to: {results_csv}")


def main():
    parser = argparse.ArgumentParser(description="Local CFD post-processor")
    parser.add_argument("--output-dir", required=True, help="Path to output directory")
    parser.add_argument("--results-csv", required=True, help="Path to results CSV file")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    results_csv = Path(args.results_csv)

    print("Local CFD Post-Processor")
    print(f"  Output dir: {output_dir}")
    print(f"  Results CSV: {results_csv}")
    print("")

    process_all_cases(output_dir, results_csv)


if __name__ == "__main__":
    main()
