#!/bin/bash
set -euo pipefail

# ============================================================
# Local CFD Pipeline Runner
# Runs the full simulation pipeline without any GCP services
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${PROJECT_ROOT}/data"
INPUT_DIR="${DATA_DIR}/input"
OUTPUT_DIR="${DATA_DIR}/output"
RESULTS_CSV="${DATA_DIR}/results.csv"
IMAGE_NAME="openfoam-cfd:local"

echo "============================================"
echo "  CFD Pipeline - Local Runner"
echo "============================================"
echo ""

# Create data directories
mkdir -p "${INPUT_DIR}" "${OUTPUT_DIR}"

# Copy geometry files to input directory (simulates GCS upload)
echo "[1/5] Preparing input data..."
for airfoil_dir in "${PROJECT_ROOT}"/geometries/*/; do
    airfoil=$(basename "$airfoil_dir")
    echo "  Copying ${airfoil} case files..."
    mkdir -p "${INPUT_DIR}/${airfoil}"
    cp -r "${airfoil_dir}"* "${INPUT_DIR}/${airfoil}/"
done

# Build the Docker image
echo ""
echo "[2/5] Building OpenFOAM container..."
docker build -t "${IMAGE_NAME}" "${PROJECT_ROOT}/docker/"

# Initialize results CSV
if [ ! -f "${RESULTS_CSV}" ]; then
    echo "case_name,airfoil,aoa,reynolds,mach,cl,cd,cm,iterations,wall_time_seconds,converged,timestamp" > "${RESULTS_CSV}"
fi

# Define cases (same as terraform/variables.tf)
declare -a CASES=(
    "naca0012_aoa0:naca0012:0:3000000:0.15"
    "naca0012_aoa2:naca0012:2:3000000:0.15"
    "naca0012_aoa4:naca0012:4:3000000:0.15"
    "naca0012_aoa6:naca0012:6:3000000:0.15"
    "naca0012_aoa8:naca0012:8:3000000:0.15"
    "naca0012_aoa10:naca0012:10:3000000:0.15"
    "naca0012_aoa12:naca0012:12:3000000:0.15"
)

# Run simulations
echo ""
echo "[3/5] Running simulations..."
echo ""

TOTAL=${#CASES[@]}
CURRENT=0
FAILED=0

for case_str in "${CASES[@]}"; do
    IFS=':' read -r CASE_NAME AIRFOIL AOA REYNOLDS MACH <<< "$case_str"
    CURRENT=$((CURRENT + 1))

    echo "  [${CURRENT}/${TOTAL}] Running ${CASE_NAME} (AoA=${AOA} deg)..."

    CASE_OUTPUT="${OUTPUT_DIR}/${CASE_NAME}"
    mkdir -p "${CASE_OUTPUT}"

    START_TIME=$(date +%s)

    # Run the container with local mounts instead of GCS
    docker run --rm \
        -v "${INPUT_DIR}:/opt/cfd/input:ro" \
        -v "${CASE_OUTPUT}:/opt/cfd/output" \
        -e CASE_NAME="${CASE_NAME}" \
        -e AIRFOIL="${AIRFOIL}" \
        -e AOA="${AOA}" \
        -e REYNOLDS="${REYNOLDS}" \
        -e MACH="${MACH}" \
        -e LOCAL_MODE="true" \
        "${IMAGE_NAME}" 2>&1 | tee "${CASE_OUTPUT}/run.log" || {
            echo "  X ${CASE_NAME} FAILED"
            FAILED=$((FAILED + 1))
            continue
        }

    END_TIME=$(date +%s)
    WALL_TIME=$((END_TIME - START_TIME))

    echo "  OK ${CASE_NAME} completed in ${WALL_TIME}s"
done

# Post-process results
echo ""
echo "[4/5] Post-processing results..."
python3 "${PROJECT_ROOT}/scripts/postprocess_local.py" \
    --output-dir "${OUTPUT_DIR}" \
    --results-csv "${RESULTS_CSV}"

# Summary
echo ""
echo "[5/5] Summary"
echo "============================================"
echo "  Total cases: ${TOTAL}"
echo "  Succeeded:   $((TOTAL - FAILED))"
echo "  Failed:      ${FAILED}"
echo "  Results:     ${RESULTS_CSV}"
echo "  Output:      ${OUTPUT_DIR}/"
echo "============================================"
echo ""

if [ -f "${RESULTS_CSV}" ]; then
    echo "Results preview:"
    if command -v column >/dev/null 2>&1; then
        column -t -s',' "${RESULTS_CSV}" | head -10
    else
        head -10 "${RESULTS_CSV}"
    fi
fi
