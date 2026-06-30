#!/bin/bash
# Note: No set -euo because OpenFOAM bashrc uses unbound vars and returns non-zero
set -o pipefail

echo "=== CFD Pipeline Starting ==="
echo "Case: ${CASE_NAME}"
echo "Airfoil: ${AIRFOIL}"
echo "AoA: ${AOA} degrees"
echo "Reynolds: ${REYNOLDS}"
echo "Mach: ${MACH}"

# Get case files
mkdir -p /opt/cfd/run

if [ "${LOCAL_MODE:-false}" = "true" ]; then
    echo "=== LOCAL MODE: Copying from mounted volume ==="
    cp -r /opt/cfd/input/${AIRFOIL}/* /opt/cfd/run/
else
    echo "=== Downloading case files from GCS ==="
    gsutil -m cp -r "gs://${GCS_INPUT_BUCKET}/${AIRFOIL}/*" /opt/cfd/run/
fi

cd /opt/cfd/run

# Modify boundary conditions for angle of attack
echo "=== Setting angle of attack to ${AOA} degrees ==="
UMAG=51.4
UX=$(python3 -c "import math; print(round(math.cos(math.radians(${AOA}))*${UMAG}, 6))")
UY=$(python3 -c "import math; print(round(math.sin(math.radians(${AOA}))*${UMAG}, 6))")
echo "Velocity: Ux=${UX}, Uy=${UY} (AoA=${AOA} deg, |U|=${UMAG} m/s)"

# Update velocity in 0/U - this is a 2D case in x-y plane (z is empty direction)
if [ -f "0/U" ]; then
    sed -i "s|internalField.*uniform.*|internalField   uniform (${UX} ${UY} 0);|" 0/U
    sed -i "s|freestreamValue.*uniform.*|freestreamValue uniform (${UX} ${UY} 0);|g" 0/U
    sed -i "s|value.*uniform (.*|value           uniform (${UX} ${UY} 0);|g" 0/U
    echo "Updated 0/U with freestream velocity"
fi

# Source OpenFOAM
echo "=== Sourcing OpenFOAM environment ==="
source /usr/lib/openfoam/openfoam2312/etc/bashrc || true

# Run meshing
echo "=== Running blockMesh ==="
blockMesh > log.blockMesh 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: blockMesh failed"
    tail -10 log.blockMesh
    exit 1
fi
tail -3 log.blockMesh

echo "=== Running snappyHexMesh ==="
snappyHexMesh -overwrite > log.snappyHexMesh 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: snappyHexMesh failed"
    tail -20 log.snappyHexMesh
    exit 1
fi
tail -5 log.snappyHexMesh

# Run solver
echo "=== Running simpleFoam ==="
START_TIME=$(date +%s)
simpleFoam > log.simpleFoam 2>&1
END_TIME=$(date +%s)
WALL_TIME=$((END_TIME - START_TIME))
echo "=== Solver completed in ${WALL_TIME} seconds ==="
tail -5 log.simpleFoam

# Extract force coefficients from the last timestep
echo "=== Extracting results ==="
COEFF_FILE=$(find postProcessing/forceCoeffs -name "coefficient.dat" 2>/dev/null | head -1)

if [ -n "$COEFF_FILE" ] && [ -f "$COEFF_FILE" ]; then
    # OpenFOAM 2312 uses tab-backtick separators. Extract numeric fields only.
    LAST_LINE=$(grep -v "^#" "$COEFF_FILE" | tail -1)
    # Remove backticks and collapse whitespace
    CLEAN_LINE=$(echo "$LAST_LINE" | tr -d '`' | tr '\t' ' ' | tr -s ' ')
    # Fields: Time Cd Cd(f) Cd(r) Cl Cl(f) Cl(r) CmPitch ...
    FINAL_CD=$(echo "$CLEAN_LINE" | awk '{print $2}')
    FINAL_CL=$(echo "$CLEAN_LINE" | awk '{print $5}')
    FINAL_CM=$(echo "$CLEAN_LINE" | awk '{print $8}')
else
    echo "Warning: No forceCoeffs output found"
    FINAL_CL="0"
    FINAL_CD="0"
    FINAL_CM="0"
fi

echo "Cl=${FINAL_CL}, Cd=${FINAL_CD}, Cm=${FINAL_CM}"

# Determine convergence
CONVERGED=false
if grep -q "SIMPLE solution converged" log.simpleFoam; then
    CONVERGED=true
fi

# Count iterations
ITERATIONS=$(grep -c "^Time = " log.simpleFoam || echo "0")

# Write metadata
mkdir -p /opt/cfd/output
cat > /opt/cfd/output/metadata.json << METADATA
{
    "case_name": "${CASE_NAME}",
    "airfoil": "${AIRFOIL}",
    "aoa": ${AOA},
    "reynolds": ${REYNOLDS},
    "mach": ${MACH},
    "cl": ${FINAL_CL},
    "cd": ${FINAL_CD},
    "cm": ${FINAL_CM},
    "iterations": ${ITERATIONS},
    "wall_time_seconds": ${WALL_TIME},
    "converged": ${CONVERGED},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "machine_type": "${MACHINE_TYPE:-local-docker}"
}
METADATA

# Copy logs
cp log.* /opt/cfd/output/ 2>/dev/null

echo "=== CFD Pipeline Complete ==="
