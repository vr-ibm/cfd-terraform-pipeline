#!/usr/bin/env python3
"""Generate NACA 0012 airfoil STL for OpenFOAM snappyHexMesh. No dependencies."""

import struct
import os
import math

def naca0012_points(num_points=100):
    points_upper = []
    points_lower = []
    for i in range(num_points):
        beta = math.pi * i / (num_points - 1)
        x = 0.5 * (1 - math.cos(beta))
        t = 0.12
        yt = 5 * t * (0.2969*math.sqrt(x) - 0.1260*x - 0.3516*x**2 + 0.2843*x**3 - 0.1015*x**4)
        points_upper.append((x, yt))
        points_lower.append((x, -yt))
    return points_upper, points_lower

def write_stl(filename, upper, lower, span=0.1):
    triangles = []
    n = len(upper)
    # Upper surface - normals pointing OUT (away from airfoil center)
    for i in range(n - 1):
        p1 = (upper[i][0], upper[i][1], 0)
        p2 = (upper[i+1][0], upper[i+1][1], 0)
        p3 = (upper[i+1][0], upper[i+1][1], span)
        p4 = (upper[i][0], upper[i][1], span)
        # Winding: outward normal for upper surface (positive y)
        triangles.append((p1, p4, p3))
        triangles.append((p1, p3, p2))
    # Lower surface - normals pointing OUT (negative y direction)
    for i in range(n - 1):
        p1 = (lower[i][0], lower[i][1], 0)
        p2 = (lower[i+1][0], lower[i+1][1], 0)
        p3 = (lower[i+1][0], lower[i+1][1], span)
        p4 = (lower[i][0], lower[i][1], span)
        # Winding: outward normal for lower surface (negative y)
        triangles.append((p1, p2, p3))
        triangles.append((p1, p3, p4))
    # Front cap (z=0) - normal pointing in -z
    for i in range(n - 1):
        triangles.append(((0.5, 0, 0), (upper[i+1][0], upper[i+1][1], 0), (upper[i][0], upper[i][1], 0)))
    for i in range(n - 1):
        triangles.append(((0.5, 0, 0), (lower[i][0], lower[i][1], 0), (lower[i+1][0], lower[i+1][1], 0)))
    # Back cap (z=span) - normal pointing in +z
    for i in range(n - 1):
        triangles.append(((0.5, 0, span), (upper[i][0], upper[i][1], span), (upper[i+1][0], upper[i+1][1], span)))
    for i in range(n - 1):
        triangles.append(((0.5, 0, span), (lower[i+1][0], lower[i+1][1], span), (lower[i][0], lower[i][1], span)))

    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, 'wb') as f:
        f.write(b'\0' * 80)
        f.write(struct.pack('<I', len(triangles)))
        for tri in triangles:
            f.write(struct.pack('<fff', 0, 0, 0))
            for vertex in tri:
                f.write(struct.pack('<fff', *vertex))
            f.write(struct.pack('<H', 0))
    print(f"Written {len(triangles)} triangles to {filename}")

if __name__ == "__main__":
    upper, lower = naca0012_points(100)
    write_stl("geometries/naca0012/constant/triSurface/naca0012.stl", upper, lower)
    print("Done!")
