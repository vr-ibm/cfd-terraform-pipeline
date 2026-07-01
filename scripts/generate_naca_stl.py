#!/usr/bin/env python3
"""Generate binary STL geometry for any 4-digit NACA airfoil."""

import math
import os
import struct
import sys


def parse_naca4(code):
    if len(code) != 4 or not code.isdigit():
        raise ValueError("NACA code must be exactly 4 digits, e.g. 0012 or 2412")

    m = int(code[0]) / 100.0
    p = int(code[1]) / 10.0
    xx = int(code[2:]) / 100.0
    return m, p, xx


def airfoil_points(code, n=100):
    m, p, xx = parse_naca4(code)
    upper = []
    lower = []

    for i in range(n + 1):
        x = 0.5 * (1.0 - math.cos(math.pi * i / n))

        yt = (xx / 0.2) * (
            0.2969 * math.sqrt(x)
            - 0.1260 * x
            - 0.3516 * x**2
            + 0.2843 * x**3
            - 0.1015 * x**4
        )

        if m == 0.0:
            yc = 0.0
            dyc_dx = 0.0
        elif x <= p:
            yc = (m / (p**2)) * (2.0 * p * x - x**2)
            dyc_dx = (2.0 * m / (p**2)) * (p - x)
        else:
            yc = (m / ((1.0 - p) ** 2)) * ((1.0 - 2.0 * p) + 2.0 * p * x - x**2)
            dyc_dx = (2.0 * m / ((1.0 - p) ** 2)) * (p - x)

        theta = math.atan(dyc_dx)

        xu = x - yt * math.sin(theta)
        yu = yc + yt * math.cos(theta)
        xl = x + yt * math.sin(theta)
        yl = yc - yt * math.cos(theta)

        upper.append((xu, yu))
        lower.append((xl, yl))

    return upper, lower


def normal_for_triangle(p1, p2, p3):
    ux, uy, uz = p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2]
    vx, vy, vz = p3[0] - p1[0], p3[1] - p1[1], p3[2] - p1[2]

    nx = uy * vz - uz * vy
    ny = uz * vx - ux * vz
    nz = ux * vy - uy * vx

    mag = math.sqrt(nx * nx + ny * ny + nz * nz)
    if mag == 0.0:
        return (0.0, 0.0, 0.0)
    return (nx / mag, ny / mag, nz / mag)


def write_binary_stl(path, upper, lower, span=0.1):
    triangles = []

    # Upper surface winding: (p1, p4, p3) and (p1, p3, p2)
    for i in range(len(upper) - 1):
        p1 = (upper[i][0], upper[i][1], 0.0)
        p2 = (upper[i + 1][0], upper[i + 1][1], 0.0)
        p3 = (upper[i + 1][0], upper[i + 1][1], span)
        p4 = (upper[i][0], upper[i][1], span)
        triangles.append((p1, p4, p3))
        triangles.append((p1, p3, p2))

    # Lower surface winding: (p1, p2, p3) and (p1, p3, p4)
    for i in range(len(lower) - 1):
        p1 = (lower[i][0], lower[i][1], 0.0)
        p2 = (lower[i + 1][0], lower[i + 1][1], 0.0)
        p3 = (lower[i + 1][0], lower[i + 1][1], span)
        p4 = (lower[i][0], lower[i][1], span)
        triangles.append((p1, p2, p3))
        triangles.append((p1, p3, p4))

    # End caps to make a closed, watertight extrusion.
    x_te = 1.0
    y_te = 0.0
    for i in range(len(upper) - 1):
        triangles.append(((x_te, y_te, 0.0), (upper[i + 1][0], upper[i + 1][1], 0.0), (upper[i][0], upper[i][1], 0.0)))
    for i in range(len(lower) - 1):
        triangles.append(((x_te, y_te, 0.0), (lower[i][0], lower[i][1], 0.0), (lower[i + 1][0], lower[i + 1][1], 0.0)))
    for i in range(len(upper) - 1):
        triangles.append(((x_te, y_te, span), (upper[i][0], upper[i][1], span), (upper[i + 1][0], upper[i + 1][1], span)))
    for i in range(len(lower) - 1):
        triangles.append(((x_te, y_te, span), (lower[i + 1][0], lower[i + 1][1], span), (lower[i][0], lower[i][1], span)))

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        header = f"NACA {os.path.basename(path)}".encode("ascii", errors="ignore")[:80]
        f.write(header + b"\0" * (80 - len(header)))
        f.write(struct.pack("<I", len(triangles)))

        for tri in triangles:
            n = normal_for_triangle(*tri)
            f.write(struct.pack("<fff", n[0], n[1], n[2]))
            for v in tri:
                f.write(struct.pack("<fff", v[0], v[1], v[2]))
            f.write(struct.pack("<H", 0))


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/generate_naca_stl.py <4-digit code>")
        sys.exit(1)

    code = sys.argv[1]
    upper, lower = airfoil_points(code, n=100)
    output = os.path.join(
        "geometries", f"naca{code}", "constant", "triSurface", f"naca{code}.stl"
    )
    write_binary_stl(output, upper, lower, span=0.1)
    print(f"Wrote binary STL to {output}")


if __name__ == "__main__":
    main()