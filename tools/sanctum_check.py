#!/usr/bin/env python3
"""Walk the sanctum from the foot of the stair.

The estate under the school is built by a different module, brought over from
another project, and dropped in at a scale and an origin. Nothing had ever
checked it: the school's flood starts at the front doors, and this is a
hundred and seventy studs underground behind a locked bookshelf.

Two things make it different from the school. It STACKS -- the chambers sit
directly above one another inside the pyramid -- so a single height map reads
the ceiling and the pyramid's outer faces instead of the floor you are
standing on, and every storey needs its own grid. And you do not walk between
chambers: a gate carries you up and a pad drops you back, so the flood has to
step through those links or the interior reads as sealed however it is wired.

    LUAU_BIN=<luau> python3 tools/sanctum_export.py
    python3 tools/sanctum_check.py
"""
import json, math, os, sys
from collections import deque

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = os.path.join(HERE, "_sanctum_export.json")

CELL = 1.0
BODY_LOW, BODY_HIGH = 0.6, 5.0
STEP_UP, STEP_DOWN = 3.0, 3.0
STEP = 2.2

# The floors of the estate, in world Y. Boulevard and Grand Hall share one;
# the four chambers ascend inside the pyramid.
LEVELS = [-170.0, -139.1, -123.5, -110.3, -99.5]

LANDMARKS = ("GrandFloor", "GoldFloor", "PlatinumFloor", "BlackFloor",
             "CrownFloor", "AtriumFloor", "BoulevardSlab", "RegistryWall",
             "Gate_", "Descent", "PriceBoard")


def aabb(part):
    r, s, p = part["r"], part["s"], part["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(p[i] - half[i], p[i] + half[i]) for i in range(3)]


def main():
    parts = json.load(open(DUMP))
    solids = [p for p in parts if p.get("cc")]
    if not solids:
        print("no collidable parts in the sanctum export")
        return 1

    boxes = [aabb(p) for p in solids]
    x_lo = min(b[0][0] for b in boxes) - 8
    z_lo = min(b[2][0] for b in boxes) - 8
    nx = int((max(b[0][1] for b in boxes) + 8 - x_lo) / CELL) + 1
    nz = int((max(b[2][1] for b in boxes) + 8 - z_lo) / CELL) + 1

    def gx(v):
        return int((v - x_lo) / CELL)

    def gz(v):
        return int((v - z_lo) / CELL)

    def span(lo, hi, origin, limit):
        first = int(math.ceil((lo - origin - CELL / 2) / CELL))
        last = int(math.floor((hi - origin - CELL / 2) / CELL)) + 1
        return max(first, 0), min(last, limit)

    def build(level):
        floor = np.full((nx, nz), -1e9, dtype=np.float32)
        ranges = []
        for box in boxes:
            x0, x1 = span(box[0][0], box[0][1], x_lo, nx)
            z0, z1 = span(box[2][0], box[2][1], z_lo, nz)
            if x1 <= x0 or z1 <= z0:
                continue
            ranges.append((x0, x1, z0, z1, box[1][0], box[1][1]))
            if level - STEP_DOWN <= box[1][1] <= level + STEP_UP:
                patch = floor[x0:x1, z0:z1]
                np.maximum(patch, box[1][1], out=patch)
        blocked = np.zeros((nx, nz), dtype=bool)
        for x0, x1, z0, z1, bottom, top in ranges:
            patch = floor[x0:x1, z0:z1]
            blocked[x0:x1, z0:z1] |= (bottom < patch + BODY_HIGH) & (top > patch + BODY_LOW)
        return (floor > -1e8) & ~blocked, floor

    grids = {level: build(level) for level in LEVELS}

    def level_for(y):
        return min(LEVELS, key=lambda level: abs(level - y))

    links_path = os.path.join(HERE, "_sanctum_links.json")
    links = json.load(open(links_path)) if os.path.exists(links_path) else []
    by_cell = {}
    for link in links:
        level = level_for(link["from"][1])
        fx, fz = gx(link["from"][0]), gz(link["from"][2])
        for dx in range(-4, 5):
            for dz in range(-4, 5):
                by_cell.setdefault((level, fx + dx, fz + dz), []).append(link)

    seen = {level: np.zeros((nx, nz), dtype=bool) for level in LEVELS}
    queue = deque()
    bad = []

    def visit(level, x, z):
        walkable, _ = grids[level]
        if 0 <= x < nx and 0 <= z < nz and walkable[x, z] and not seen[level][x, z]:
            seen[level][x, z] = True
            queue.append((level, x, z))
            return True
        return False

    entrance = json.load(open(os.path.join(HERE, "_sanctum_entrance.json")))
    ground = level_for(entrance[1])
    started = False
    ex, ez = gx(entrance[0]), gz(entrance[2])
    for dx in range(-8, 9):
        for dz in range(-8, 9):
            started = visit(ground, ex + dx, ez + dz) or started
    if not started:
        bad.append(("the stair arrives", entrance, "on nothing standable"))

    while queue:
        level, x, z = queue.popleft()
        walkable, floor = grids[level]
        here = floor[x, z]
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = x + dx, z + dz
            if (0 <= a < nx and 0 <= b < nz and walkable[a, b]
                    and not seen[level][a, b] and abs(floor[a, b] - here) <= STEP):
                seen[level][a, b] = True
                queue.append((level, a, b))
        for link in by_cell.get((level, x, z), ()):
            to_level = level_for(link["to"][1])
            tx, tz = gx(link["to"][0]), gz(link["to"][2])
            landed = any(
                visit(to_level, tx + dx, tz + dz)
                for dx in range(-5, 6)
                for dz in range(-5, 6)
            )
            already = seen[to_level][max(tx - 5, 0):tx + 6, max(tz - 5, 0):tz + 6].any()
            if not landed and not already:
                bad.append((link["l"], [round(v, 1) for v in link["to"]],
                            "the pad lands you on nothing standable"))

    checked = 0
    for part in solids:
        if not any(word in part["n"] for word in LANDMARKS):
            continue
        checked += 1
        box = aabb(part)
        level = level_for(box[1][0])
        cx, cz = gx(part["p"][0]), gz(part["p"][2])
        window = seen[level][max(cx - 10, 0):cx + 11, max(cz - 10, 0):cz + 11]
        if not window.any():
            bad.append((part["n"], [round(v, 1) for v in part["p"]],
                        f"nothing reached on the {level:.0f} storey within ten studs"))

    total_seen = sum(int(seen[level].sum()) for level in LEVELS)
    for name, point, why in bad:
        print(f"  {name:26s} {point}  {why}")
    print(f"{'FAIL' if bad else 'PASS'} - sanctum: {checked} landmarks over "
          f"{len(LEVELS)} storeys, {len(links)} pads, {total_seen} cells reached")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
