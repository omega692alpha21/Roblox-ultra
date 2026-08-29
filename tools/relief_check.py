#!/usr/bin/env python3
"""Is the dressing on a wall actually OUTSIDE the wall?

kit_check counts the members: a plinth, a string course, a cornice, four
quoins, a gutter, a downpipe. It counts them by name, and a part named
PlanCornice satisfies it wherever that part happens to be.

On all five of the drawn buildings, every one of those members was INSIDE the
masonry. PlanBuilder sized them off the rectangle CampusPlan draws -- plinth
at width + 3.0, cornice at width + 3.4 -- and the exterior wall straddles that
rectangle line eight studs thick, so the face a player sees stands four studs
further out. Plinth 2.5 studs inside the wall. Cornice 2.3 inside. Quoins 2.5
inside. Gutters and downpipes wholly buried in it.

Five buildings with a full set of dressing and not one member of it visible:
flat walls, no relief, and every check in this repo passing.

This measures the thing kit_check assumes. For each dressing member it finds
the wall it sits on and asks how far it stands proud of that wall's face.

    python3 tools/render_map.py .
    python3 tools/relief_check.py
"""
import json, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

DRESSING = ("Plinth", "StringCourse", "Cornice", "Quoin", "Gutter", "Downpipe",
            "Hopper", "Buttress", "Pilaster", "Band", "Coping", "Kneeler")
WALLS = ("Wall", "Facade", "Brick", "Shell", "Range", "Tower", "Gable")
NOT_WALL = ("Inner", "Partition", "Cavern", "Tunnel", "Boundary", "Retain",
            "Head", "Upper", "Lower")
CELL = 32.0
PROUD = 0.4          # studs a member must stand out of its wall
SHARE = 0.15         # ... on at least this share of its length


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(q[i] - half[i], q[i] + half[i]) for i in range(3)]


def main():
    parts = json.load(open(DUMP))
    walls = []
    for p in parts:
        n = p["n"]
        if any(w in n for w in NOT_WALL) or not any(w in n for w in WALLS):
            continue
        b = aabb(p)
        if b[1][1] - b[1][0] < 5.0:
            continue
        walls.append(b)
    if not walls:
        print("FAIL - no walls found; the name list is wrong")
        return 1

    grid = defaultdict(list)
    for b in walls:
        for cx in range(int(b[0][0] // CELL), int(b[0][1] // CELL) + 1):
            for cz in range(int(b[2][0] // CELL), int(b[2][1] // CELL) + 1):
                grid[(cx, cz)].append(b)

    flat, measured = [], 0
    for p in parts:
        n = p["n"]
        if not any(w in n for w in DRESSING):
            continue
        b = aabb(p)
        near = []
        for cx in range(int(b[0][0] // CELL), int(b[0][1] // CELL) + 1):
            for cz in range(int(b[2][0] // CELL), int(b[2][1] // CELL) + 1):
                near.extend(grid.get((cx, cz), ()))
        if not near:
            continue                    # nothing to dress; not this check's business
        measured += 1
        # How far does this member reach past the nearest wall face, on either
        # horizontal axis, in either direction?
        best = -1e9
        for axis in (0, 2):
            for sign in (-1, 1):
                edge = b[axis][1] if sign > 0 else -b[axis][0]
                for w in near:
                    # the wall has to actually overlap this member on the OTHER
                    # horizontal axis and in height, or it is a different wall
                    other = 2 if axis == 0 else 0
                    if b[other][1] <= w[other][0] or b[other][0] >= w[other][1]:
                        continue
                    if b[1][1] <= w[1][0] or b[1][0] >= w[1][1]:
                        continue
                    face = w[axis][1] if sign > 0 else -w[axis][0]
                    best = max(best, edge - face)
        if best > -1e8 and best < PROUD:
            flat.append((best, n, [round(v) for v in p["p"]]))

    print(f"{measured} dressing members measured against the walls they sit on")
    if flat:
        seen, shown = set(), 0
        flat.sort()
        for proud, name, pos in flat:
            if name in seen and shown > 12:
                continue
            seen.add(name)
            shown += 1
            if shown <= 14:
                print(f"  {proud:+5.1f} proud  {name:22} at {pos}")
        kinds = sorted({f[1] for f in flat})
        print(f"FAIL - {len(flat)} members flush with or inside their wall "
              f"({len(kinds)} kinds: {', '.join(kinds[:8])})")
        return 1
    print("PASS - every course, quoin and pipe stands proud of its wall")
    return 0


if __name__ == "__main__":
    sys.exit(main())
