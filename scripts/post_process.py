#!/usr/bin/env python3
"""Post-process CFD results from output directories into a CSV."""
import csv
import json
import os


def main():
    output_dir = os.environ.get("OUTPUT_DIR", "data/output")
    results_csv = os.environ.get("RESULTS_CSV", "data/results.csv")

    print("Local CFD Post-Processor")
    print(f"  Output dir: {os.path.abspath(output_dir)}")
    print(f"  Results CSV: {os.path.abspath(results_csv)}")
    print()

    fields = ["case_name", "airfoil", "aoa", "reynolds", "mach",
              "cl", "cd", "cm", "iterations", "wall_time_seconds",
              "converged", "timestamp", "machine_type"]

    rows = []
    for case_dir in sorted(os.listdir(output_dir)):
        meta_path = os.path.join(output_dir, case_dir, "metadata.json")
        if not os.path.isfile(meta_path):
            continue
        print(f"  Processing: {case_dir}")
        with open(meta_path) as f:
            data = json.load(f)
        print(f"    Cl={data.get('cl')}, Cd={data.get('cd')}, Cm={data.get('cm')}")
        rows.append(data)

    rows.sort(key=lambda r: r.get("aoa", 0))

    os.makedirs(os.path.dirname(results_csv), exist_ok=True)
    with open(results_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    print(f"\n  Results written to: {os.path.abspath(results_csv)}")
    print(f"  Total cases: {len(rows)}")


if __name__ == "__main__":
    main()
