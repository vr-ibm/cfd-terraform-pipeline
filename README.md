# CFD Terraform Pipeline
Automated computational fluid dynamics (CFD) pipeline for aerodynamic coefficient sweeps, built on OpenFOAM and designed to run locally via Docker or at scale on GCP infrastructure provisioned with Terraform.

## What It Does
Runs parametric angle-of-attack sweeps on airfoil geometries using OpenFOAM's simpleFoam solver with snappyHexMesh, producing lift (Cl), drag (Cd), and moment (Cm) coefficients. Results are collected into a CSV for analysis or upload to BigQuery.

## Architecture
```text
geometries/         ← OpenFOAM case files + STL per airfoil
docker/             ← Dockerfile + entrypoint.sh (mesh → solve → extract)
scripts/            ← run_local.sh, post_process.py, generate STL
terraform/          ← GCP infrastructure (GCE, GCS, BigQuery)
data/output/        ← per-case metadata.json + solver logs
data/results.csv    ← aggregated results
```

## Quick Start

### Prerequisites
- Docker Desktop
- Python 3.8+

### Run Locally
```bash
# Generate the airfoil STL (one-time)
python3 scripts/generate_naca0012_stl.py

# Build the solver image
docker build -t openfoam-cfd:local docker/

# Run the full AoA sweep (0°–12°, ~7 cases, ~5 min total)
./scripts/run_local.sh
```

Results land in `data/results.csv`:
```text
case_name,airfoil,aoa,reynolds,mach,cl,cd,cm,...
naca0012_aoa0,naca0012,0,3000000,0.15,-0.038,0.017,0.011,...
naca0012_aoa4,naca0012,4,3000000,0.15,0.270,0.007,0.020,...
naca0012_aoa12,naca0012,12,3000000,0.15,0.695,0.000,-0.039,...
```

### Run a Single Case
```bash
docker run --rm \
  -v "$(pwd)/geometries/naca0012:/opt/cfd/input/naca0012:ro" \
  -v "$(pwd)/data/output/test:/opt/cfd/output" \
  -e CASE_NAME=test -e AIRFOIL=naca0012 -e AOA=4 \
  -e REYNOLDS=3000000 -e MACH=0.15 -e LOCAL_MODE=true \
  openfoam-cfd:local
```

## Pipeline Steps
- `blockMesh` — generates base hexahedral mesh around the domain
- `snappyHexMesh` — refines mesh and snaps to airfoil STL surface
- `simpleFoam` — steady-state RANS solver (2000 iterations)
- `forceCoeffs` — extracts Cl, Cd, Cm from converged flow field
- `post_process.py` — aggregates per-case `metadata.json` into `results.csv`

## Configuration
Simulation parameters are set via environment variables:

| Variable | Description | Default |
| --- | --- | --- |
| `AIRFOIL` | Geometry name (maps to `geometries/` subdir) | `naca0012` |
| `AOA` | Angle of attack in degrees | `0` |
| `REYNOLDS` | Reynolds number | `3000000` |
| `MACH` | Freestream Mach number | `0.15` |
| `LOCAL_MODE` | Use mounted volume instead of GCS | `true` |

## Project Structure
```text
├── docker/
│   ├── Dockerfile              # OpenFOAM 2312 + gcloud SDK
│   └── entrypoint.sh           # Mesh → solve → extract pipeline
├── geometries/
│   └── naca0012/
│       ├── 0/                  # Initial/boundary conditions (U, p, nut, etc.)
│       ├── constant/
│       │   ├── triSurface/     # Airfoil STL
│       │   └── transportProperties
│       └── system/
│           ├── blockMeshDict
│           ├── controlDict
│           ├── fvSchemes
│           ├── fvSolution
│           └── snappyHexMeshDict
├── scripts/
│   ├── generate_naca0012_stl.py
│   ├── post_process.py
│   └── run_local.sh
├── terraform/                  # GCP infra (future)
└── data/
    ├── output/                 # Per-case results
    └── results.csv             # Aggregated sweep data
```

## Solver Details
- Turbulence model: Spalart-Allmaras (SA)
- Mesh: ~200k cells after snappyHexMesh refinement (levels 4-5 near airfoil)
- Convergence: 2000 iterations or residuals < 1e-5
- Reference values: `magUInf=51.4 m/s`, `Aref=0.1 m²`, `lRef=1 m`, `rhoInf=1.225 kg/m³`

## Known Limitations
- 2D simulation (single cell in z-direction with empty BC) — no 3D effects
- No boundary layer mesh (addLayers disabled) — Cd values are approximate
- Coarse mesh trades accuracy for speed (~30s mesh + ~25s solve per case)
- Cl slope is ~60% of thin airfoil theory due to mesh resolution

## Roadmap
- [ ] Terraform-provisioned GCE spot instances for parallel sweeps
- [ ] GCS bucket for case file storage and result collection
- [ ] BigQuery table for historical coefficient data
- [ ] Additional airfoil geometries (NACA 4-digit series)
- [ ] Boundary layer meshing for accurate Cd prediction
- [ ] Automated Cl-alpha curve plotting
