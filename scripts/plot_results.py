#!/usr/bin/env python3
"""Plot Cl vs AoA: simulation vs experimental data."""

import argparse
import csv
import json
import os


try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    HAS_MPL = True
except ImportError:
    HAS_MPL = False


def read_simulation_data(csv_path):
    sim_points = {"naca0012": [], "naca2412": []}
    with open(csv_path, newline="", encoding="utf-8") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            airfoil = row.get("airfoil")
            if airfoil not in sim_points:
                continue
            try:
                aoa = float(row["aoa"])
                cl = float(row["cl"])
            except (KeyError, TypeError, ValueError):
                continue
            sim_points[airfoil].append((aoa, cl))

    out = {}
    for airfoil, points in sim_points.items():
        points.sort(key=lambda x: x[0])
        out[airfoil] = ([p[0] for p in points], [p[1] for p in points])
    return out


def save_chartjs_html(output_path, sim_data, exp0012_aoa, exp0012_cl, exp2412_aoa, exp2412_cl):
    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NACA Airfoil Lift Curves - Simulation vs Experiment</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    .container {{ max-width: 1000px; margin: 0 auto; }}
    h1 {{ margin-bottom: 8px; }}
    p.note {{ font-size: 13px; color: #444; font-style: italic; }}
    canvas {{ width: 100%; height: 520px; }}
  </style>
</head>
<body>
  <div class="container">
    <h1>NACA Airfoil Lift Curves - Simulation vs Experiment</h1>
    <canvas id="chart"></canvas>
    <p class="note">Note: Simulation uses coarse mesh without boundary layer - expect ~60% of experimental Cl slope</p>
  </div>

  <script>
    const sim0012Aoa = {json.dumps(sim_data["naca0012"][0])};
    const sim0012Cl = {json.dumps(sim_data["naca0012"][1])};
    const sim2412Aoa = {json.dumps(sim_data["naca2412"][0])};
    const sim2412Cl = {json.dumps(sim_data["naca2412"][1])};
    const exp0012Aoa = {json.dumps(exp0012_aoa)};
    const exp0012Cl = {json.dumps(exp0012_cl)};
    const exp2412Aoa = {json.dumps(exp2412_aoa)};
    const exp2412Cl = {json.dumps(exp2412_cl)};

    const sim0012Data = sim0012Aoa.map((x, i) => ({{ x: x, y: sim0012Cl[i] }}));
    const sim2412Data = sim2412Aoa.map((x, i) => ({{ x: x, y: sim2412Cl[i] }}));
    const exp0012Data = exp0012Aoa.map((x, i) => ({{ x: x, y: exp0012Cl[i] }}));
    const exp2412Data = exp2412Aoa.map((x, i) => ({{ x: x, y: exp2412Cl[i] }}));

    const ctx = document.getElementById('chart').getContext('2d');
    new Chart(ctx, {{
      type: 'line',
      data: {{
        datasets: [
          {{
            label: 'OpenFOAM naca0012 (coarse mesh)',
            data: sim0012Data,
            borderColor: '#2563eb',
            backgroundColor: '#2563eb',
            pointRadius: 4,
            pointStyle: 'circle',
            borderWidth: 2,
            tension: 0
          }},
          {{
            label: 'OpenFOAM naca2412 (coarse mesh)',
            data: sim2412Data,
            borderColor: '#16a34a',
            backgroundColor: '#16a34a',
            pointRadius: 4,
            pointStyle: 'rect',
            borderWidth: 2,
            tension: 0
          }},
          {{
            label: 'Experimental naca0012 (Re=3x10^6)',
            data: exp0012Data,
            borderColor: '#dc2626',
            backgroundColor: '#dc2626',
            pointRadius: 5,
            pointStyle: 'triangle',
            borderDash: [6, 4],
            borderWidth: 2,
            tension: 0
          }},
          {{
            label: 'Experimental naca2412 (Re=3x10^6)',
            data: exp2412Data,
            borderColor: '#f97316',
            backgroundColor: '#f97316',
            pointRadius: 5,
            pointStyle: 'rectRot',
            borderDash: [6, 4],
            borderWidth: 2,
            tension: 0
          }}
        ]
      }},
      options: {{
        responsive: true,
        maintainAspectRatio: false,
        parsing: false,
        scales: {{
          x: {{
            type: 'linear',
            title: {{ display: true, text: 'Angle of Attack (degrees)' }}
          }},
          y: {{
            title: {{ display: true, text: 'Lift Coefficient (Cl)' }}
          }}
        }},
        plugins: {{
          title: {{
            display: true,
            text: 'NACA Airfoil Lift Curves - Simulation vs Experiment'
          }},
          legend: {{
            display: true
          }}
        }}
      }}
    }});
  </script>
</body>
</html>
"""
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)


def main():
    parser = argparse.ArgumentParser(description="Plot Cl vs AoA for NACA airfoils")
    parser.add_argument("--csv", default="data/results.csv")
    parser.add_argument("--output", default="data/cl_vs_aoa.png")
    args = parser.parse_args()

    csv_path = args.csv
    output_path = args.output

    sim_data = read_simulation_data(csv_path)

    exp0012_aoa = [0, 2, 4, 6, 8, 10, 12]
    exp0012_cl = [0.000, 0.220, 0.440, 0.660, 0.870, 1.040, 1.090]
    exp2412_aoa = [-2, 0, 2, 4, 6, 8, 10]
    exp2412_cl = [0.000, 0.250, 0.470, 0.690, 0.900, 1.080, 1.200]

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    if HAS_MPL:
        plt.figure(figsize=(10, 6))
        sim0012_aoa, sim0012_cl = sim_data["naca0012"]
        sim2412_aoa, sim2412_cl = sim_data["naca2412"]
        if sim0012_aoa:
            plt.plot(sim0012_aoa, sim0012_cl, "bo-", label="OpenFOAM naca0012 (coarse mesh)")
        if sim2412_aoa:
            plt.plot(sim2412_aoa, sim2412_cl, "gs-", label="OpenFOAM naca2412 (coarse mesh)")
        plt.plot(exp0012_aoa, exp0012_cl, "r^--", label="Experimental naca0012 (Re=3x10^6)")
        plt.plot(exp2412_aoa, exp2412_cl, "D--", color="orange", label="Experimental naca2412 (Re=3x10^6)")
        plt.xlabel("Angle of Attack (degrees)")
        plt.ylabel("Lift Coefficient (Cl)")
        plt.title("NACA Airfoil Lift Curves — Simulation vs Experiment")
        plt.legend()
        plt.grid(True)
        plt.figtext(
            0.5,
            0.01,
            "Note: Simulation uses coarse mesh without boundary layer — expect ~60% of experimental Cl slope",
            ha="center",
            fontsize=8,
            style="italic",
        )
        plt.tight_layout(rect=[0, 0.03, 1, 1])
        plt.savefig(output_path, dpi=150)
        print(f"Saved plot to {output_path}")
    else:
        root, _ = os.path.splitext(output_path)
        output_path = root + ".html"
        save_chartjs_html(
            output_path,
            sim_data,
            exp0012_aoa,
            exp0012_cl,
            exp2412_aoa,
            exp2412_cl,
        )
        print(f"Saved HTML chart to {output_path}")


if __name__ == "__main__":
    main()
