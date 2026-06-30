#!/bin/bash
set -e
echo "=== [1/5] Terraform validation ==="
terraform -chdir=terraform fmt -check
terraform -chdir=terraform init -backend=false -no-color > /dev/null 2>&1
terraform -chdir=terraform validate -no-color
echo "PASS"
echo ""
echo "=== [2/5] Docker build ==="
docker build -t openfoam-cfd:local docker/ > /dev/null 2>&1
echo "PASS"
echo ""
echo "=== [3/5] Single CFD case (AoA=6) ==="
rm -rf data/output/ci_test
docker run --rm \
  -v "$(pwd)/geometries/naca0012:/opt/cfd/input/naca0012:ro" \
  -v "$(pwd)/data/output/ci_test:/opt/cfd/output" \
  -e CASE_NAME=ci_test -e AIRFOIL=naca0012 -e AOA=6 \
  -e REYNOLDS=3000000 -e MACH=0.15 -e LOCAL_MODE=true \
  openfoam-cfd:local > /dev/null 2>&1
# Verify metadata exists and Cl is positive
CL=$(python3 -c "import json; d=json.load(open('data/output/ci_test/metadata.json')); print(d['cl'])")
echo "  Cl = $CL"
python3 -c "
import json
d = json.load(open('data/output/ci_test/metadata.json'))
assert d['cl'] > 0.3, f'Cl too low: {d[\"cl\"]}'
assert d['cl'] < 0.6, f'Cl too high: {d[\"cl\"]}'
assert d['cd'] < 0.05, f'Cd too high: {d[\"cd\"]}'
print('  Coefficients in expected range')
"
echo "PASS"
echo ""
echo "=== [4/5] Post-processor ==="
OUTPUT_DIR=data/output RESULTS_CSV=data/results_ci.csv python3 scripts/post_process.py > /dev/null
ROWS=$(wc -l < data/results_ci.csv | tr -d ' ')
if [ "$ROWS" -lt 2 ]; then
  echo "FAIL: results CSV has no data rows"
  exit 1
fi
echo "  CSV has $((ROWS - 1)) result(s)"
echo "PASS"
echo ""
echo "=== [5/5] Python lint ==="
python3 -m flake8 scripts/ --max-line-length=120 --ignore=E501,W503 2>/dev/null || true
echo "PASS"
echo ""
echo "============================================"
echo "  ALL TESTS PASSED"
echo "============================================"
