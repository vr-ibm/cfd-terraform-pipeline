#!/bin/bash
set -euo pipefail

echo "=== CFD Pipeline Starting (LOCAL MODE) ==="
echo "Case: ${CASE_NAME}"
echo "Airfoil: ${AIRFOIL}"
echo "AoA: ${AOA} degrees"
echo "Reynolds: ${REYNOLDS}"
echo "Mach: ${MACH}"

mkdir -p /opt/cfd/run
cp -r /opt/cfd/input/${AIRFOIL}/* /opt/cfd/run/

cd /opt/cfd/run

echo "=== Setting angle of attack to ${AOA} degrees ==="
AOA_RAD=$(python3 -c "import math; print(math.radians(${AOA}))")
UX=$(python3 -c "import math; print(round(math.cos(math.radians(${AOA})), 10))")
UZ=$(python3 -c "import math; print(round(math.sin(math.radians(${AOA})), 10))")

echo "Velocity components: Ux=${UX}, Uz=${UZ}"

if [ -f "0/U" ]; then
    sed -i "s/internalField.*/internalField   uniform (${UX} 0 ${UZ});/" 0/U
    sed -i "s/value.*uniform.*(.*0.*0.*)/value           uniform (${UX} 0 ${UZ})/" 0/U
fi

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

echo "=== Running postProcess for force coefficients ==="
postProcess -func forceCoeffs 2>&1 | tail -5 || echo "Warning: forceCoeffs postProcess failed, continuing..."

echo "=== Saving results to output mount ==="
if [ -d "postProcessing" ]; then
    cp -r postProcessing /opt/cfd/output/
fi

LATEST_TIME=$(foamListTimes -latestTime 2>/dev/null | tail -1 || echo "")
if [ -n "${LATEST_TIME}" ] && [ -d "${LATEST_TIME}" ]; then
    mkdir -p /opt/cfd/output/fields
    cp -r "${LATEST_TIME}" /opt/cfd/output/fields/
fi

cat > /opt/cfd/output/metadata.json << METADATA
{
    "case_name": "${CASE_NAME}",
    "airfoil": "${AIRFOIL}",
    "aoa": ${AOA},
    "reynolds": ${REYNOLDS},
    "mach": ${MACH},
    "wall_time_seconds": ${WALL_TIME},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "machine_type": "local-docker"
}
METADATA

echo "=== CFD Pipeline Complete ==="
exit 0
