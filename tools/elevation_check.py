#!/usr/bin/env python3
"""Find an elevation that reads black at night.

nightlight_check.py asks whether the GROUND a player crosses is lit. Nothing
asks it of the buildings, and the buildings are what the reference art is: the
Academy front and the dorm courtyard, both photographed at night, both lit by
the fittings hung on their own walls as much as by the standards on the paving.

A building whose ground floor has no fitting on it is a black band under a lit
first floor. That is exactly what the dorm range was, and no check in this repo
could see it -- every window in it was lit, every walk in front of it was lit,
and it still read as a silhouette.

The measurement is nightlight_check's, turned ninety degrees: take each large
outward-facing wall panel, sample its face on a grid, and sum the direct light
reaching each sample from every PointLight in the map, cosine-weighted against
the WALL's normal rather than against up. A panel most of whose face is dark
is an elevation nobody lit.

    python3 tools/render_map.py .
    python3 tools/elevation_check.py
"""
import json, math, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

WALLS = ("Wall", "Facade", "Brick", "Range", "Shell", "Block")
# Interiors, retaining walls and things that merely have "Wall" in the name.
NOT = ("Inner", "Partition", "Wainscot", "Cavern", "Shaft", "Sanctum", "Tunnel",
       "Boundary", "Retain", "Kerb", "Lamp", "Light", "Head", "Base", "Upper",
       "Stone", "Fence", "Pier", "Alley", "Turret", "Quarters")

STEP = 9.0            # sample spacing across the face
MIN_AREA = 700.0      # square studs -- a small panel is dressing, not elevation
DARK = 0.030          # below this the wall is not lit
DARK_SHARE = 0.80     # ... and it fails only if this much of it is dark
CLEAR = 3.0           # how far out to probe for "is this face exposed"
SKY = 26.0            # ignore anything above this: an upper storey and a
                      # gable are lit by the sky, not by fittings you can hang


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(q[i] - half[i], q[i] + half[i]) for i in range(3)]


def local(part, point):
    r = part["r"]
    d = [point[i] - part["p"][i] for i in range(3)]
    return [sum(r[row * 3 + col] * d[row] for row in range(3)) for col in range(3)]


def inside(part, point, pad=0.0):
    q = local(part, point)
    s = part["s"]
    return all(abs(q[i]) <= s[i] / 2 + pad for i in range(3))


def main():
    parts = json.load(open(DUMP))

    lights = []
    for p in parts:
        for lamp in p.get("lamps") or ():
            lights.append((p["p"][0], p["p"][1], p["p"][2], float(lamp[0]), float(lamp[1])))
    if not lights:
        print("FAIL - no lights in the dump at all")
        return 1

    CELL = 64.0
    grid = defaultdict(list)
    for i, (lx, _ly, lz, rng, _b) in enumerate(lights):
        span = int(rng // CELL) + 1
        for dx in range(-span, span + 1):
            for dz in range(-span, span + 1):
                grid[(int(lx // CELL) + dx, int(lz // CELL) + dz)].append(i)

    solid = defaultdict(list)
    for p in parts:
        if (p.get("t") or 0.0) >= 0.5:
            continue
        b = aabb(p)
        for cx in range(int(b[0][0] // CELL), int(b[0][1] // CELL) + 1):
            for cz in range(int(b[2][0] // CELL), int(b[2][1] // CELL) + 1):
                solid[(cx, cz)].append(p)

    def landing(x, y, z, n):
        total = 0.0
        for i in grid.get((int(x // CELL), int(z // CELL)), ()):
            lx, ly, lz, rng, bright = lights[i]
            d = (lx - x, ly - y, lz - z)
            d2 = d[0] * d[0] + d[1] * d[1] + d[2] * d[2]
            if d2 >= rng * rng:
                continue
            dist = math.sqrt(d2) or 1e-6
            cos = (d[0] * n[0] + d[1] * n[1] + d[2] * n[2]) / dist
            if cos <= 0:
                continue
            fall = 1.0 - dist / rng
            total += bright * cos * fall * fall
        return total

    def exposed(part, point, n):
        probe = [point[i] + n[i] * CLEAR for i in range(3)]
        for other in solid.get((int(probe[0] // CELL), int(probe[2] // CELL)), ()):
            if other is part:
                continue
            if inside(other, probe, pad=-0.05):
                return False
        return True

    bad, panels = [], 0
    for p in parts:
        n = p["n"]
        if any(w in n for w in NOT) or not any(w in n for w in WALLS):
            continue
        b = aabb(p)
        if b[1][0] > 2.0 or b[1][1] < 6.0:      # not founded on the ground
            continue
        w, h, d = (b[i][1] - b[i][0] for i in range(3))
        if h < 6.0:
            continue
        # the thin axis is the one the face looks along
        if d < w * 0.5:
            axis, span = 2, w
        elif w < d * 0.5:
            axis, span = 0, d
        else:
            continue
        top = min(b[1][1], SKY)
        if top - b[1][0] < 6.0 or span * (top - b[1][0]) < MIN_AREA:
            continue
        for sign in (-1, 1):
            normal = [0.0, 0.0, 0.0]
            normal[axis] = float(sign)
            face = b[axis][1] + 0.4 if sign > 0 else b[axis][0] - 0.4
            other = 0 if axis == 2 else 2
            pts = dark = seen = 0
            a = b[other][0] + STEP / 2
            while a < b[other][1]:
                y = max(b[1][0], 1.0) + STEP / 2
                while y < top:
                    q = [0.0, 0.0, 0.0]
                    q[axis], q[other], q[1] = face, a, y
                    if exposed(p, q, normal):
                        seen += 1
                        pts += 1
                        if landing(q[0], q[1], q[2], normal) < DARK:
                            dark += 1
                    y += STEP
                a += STEP
            if seen < 6:            # an internal or buried face; not an elevation
                continue
            panels += 1
            if dark / pts > DARK_SHARE:
                bad.append((dark / pts, n, [round(v) for v in p["p"]],
                            round(span * (top - b[1][0])), "-+"[sign > 0] + "xyz"[axis]))

    print(f"{panels} exposed elevations measured")
    if bad:
        bad.sort(reverse=True)
        for share, name, pos, area, face in bad[:24]:
            print(f"  {share:.0%} dark  {name:20} at {pos} face {face}  {area} sq studs")
        print(f"FAIL - {len(bad)} elevations have no light on them")
        return 1
    print("PASS - every exposed elevation carries light")
    return 0


if __name__ == "__main__":
    sys.exit(main())
