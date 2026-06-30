#!/bin/bash
set -euo pipefail

# ============================================================
# CFD Pipeline Entrypoint
# Runs an OpenFOAM simulation for a given airfoil case
# ============================================================

echo "=== CFD Pipeline Starting ==="
echo "Case: ${CASE_NAME}"
echo "Airfoil: ${AIRFOIL}"
echo "AoA: ${AOA} degrees"
echo "Reynolds: ${REYNOLDS}"
echo "Mach: ${MACH}"
echo "=== Downloading case files ==="

# Download case files from GCS input bucket
mkdir -p /opt/cfd/run
gsutil -m cp -r "gs://${GCS_INPUT_BUCKET}/${AIRFOIL}/*" /opt/cfd/run/

cd /opt/cfd/run

# ============================================================
# Modify boundary conditions for angle of attack
# ============================================================
echo "=== Setting angle of attack to ${AOA} degrees ==="

# Convert AoA to radians and compute velocity components
# Freestream velocity magnitude = 1 (normalized)
AOA_RAD=$(python3 -c "import math; print(math.radians(${AOA}))")
UX=$(python3 -c "import math; print(round(math.cos(math.radians(${AOA})), 10))")
UZ=$(python3 -c "import math; print(round(math.sin(math.radians(${AOA})), 10))")

echo "Velocity components: Ux=${UX}, Uz=${UZ}"

# Update the inlet velocity in 0/U
if [ -f "0/U" ]; then
	sed -i "s/internalField.*/internalField   uniform (${UX} 0 ${UZ});/" 0/U
	# Also update the freestream boundary condition if it exists
	sed -i "s/value.*uniform.*(.*0.*0.*)/value           uniform (${UX} 0 ${UZ})/" 0/U
fi

# ============================================================
# Source OpenFOAM environment and run simulation
# ============================================================
echo "=== Sourcing OpenFOAM environment ==="
source /usr/lib/openfoam/openfoam2312/etc/bashrc || true

echo "=== Running blockMesh ==="
blockMesh 2>&1 | tail -5

echo "=== Running simpleFoam ==="
START_TIME=$(date +%s)
simpleFoam 2>&1 | tail -20
END_TIME=$(date +%s)
WALL_TIME=$((END_TIME - START_TIME))

echo "=== Solver completed in ${WALL_TIME} seconds ==="

# ============================================================
# Post-process: extract force coefficients
# ============================================================
echo "=== Running postProcess for force coefficients ==="
postProcess -func forceCoeffs 2>&1 | tail -5 || echo "Warning: forceCoeffs postProcess failed, continuing..."

# ============================================================
# Upload results to GCS output bucket
# ============================================================
echo "=== Uploading results to GCS ==="

# Upload postProcessing directory (force coefficients)
if [ -d "postProcessing" ]; then
	gsutil -m cp -r postProcessing "gs://${GCS_OUTPUT_BUCKET}/${CASE_NAME}/"
fi

# Upload the final time step fields (for Cp visualization)
LATEST_TIME=$(foamListTimes -latestTime 2>/dev/null | tail -1 || echo "")
if [ -n "${LATEST_TIME}" ] && [ -d "${LATEST_TIME}" ]; then
	gsutil -m cp -r "${LATEST_TIME}" "gs://${GCS_OUTPUT_BUCKET}/${CASE_NAME}/fields/"
fi

# Upload a metadata JSON file with run info
cat > /tmp/metadata.json << METADATA
{
	"case_name": "${CASE_NAME}",
	"airfoil": "${AIRFOIL}",
	"aoa": ${AOA},
	"reynolds": ${REYNOLDS},
	"mach": ${MACH},
	"wall_time_seconds": ${WALL_TIME},
	"timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
	"machine_type": "${MACHINE_TYPE:-unknown}"
}
METADATA
gsutil cp /tmp/metadata.json "gs://${GCS_OUTPUT_BUCKET}/${CASE_NAME}/metadata.json"

echo "=== CFD Pipeline Complete ==="
echo "Results uploaded to: gs://${GCS_OUTPUT_BUCKET}/${CASE_NAME}/"
exit 0
