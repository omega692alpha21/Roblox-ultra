#!/usr/bin/env python3
"""How much of this school is a surface with nothing on it?

Every interior picture of the Academy is half ceiling: the main hallway's
soffit is one slab 448 by 32, the atrium's is another, the refectory's another,
and all three render as an unbroken field of one colour over whatever detail is
below them. Twenty-two checks pass over that, because not one of them asks the
question a person asks looking at the picture -- is there ANYTHING on this
surface.

relief_check measures whether a piece of dressing stands proud of its wall.
This measures the other side of that: whether a wall, floor or ceiling has any
dressing on it at all. For every large flat face in the map it samples a grid
over the face, marches a short way out along the face's own normal, and asks
whether anything is standing there. A face nothing stands on, nothing hangs
from and nothing is fixed to is a blank surface, and blank surface is the one
thing every shot of this game has too much of.

    python3 tools/render_map.py . tools && python3 tools/blank_check.py
"""
import json, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

# A face has to be big enough that a player reads it as a surface rather than
# as a piece of something. 1,200 square studs is a 35-stud square.
BIG = 1200.0
STEP = 4.0          # sample pitch across the face
# How far off the face to look for relief. It starts at 0.9, not at nothing: a
# ceiling panel laid flush IS attached to the ceiling and this check found it,
# so the main hallway's soffit came back "dressed" while every picture of it is
# a blank grey field. What separates a surface that reads as modelled from one
# that reads as a slab is RELIEF -- something standing a stud or more off it --
# which is the same bar tools/relief_check.py holds dressing to.
#
# And it is a SCAN, not three fixed distances. Three of them straddled the
# 0.35-stud gap between the upper deck and the soffit under it, so a ceiling
# with a floor slab lying right on top of it read as a hundred per cent bare.
RELIEF = [0.9 + 0.3 * i for i in range(12)]
# ... and anything closer than this means the face is not a visible surface at
# all: it is sandwiched against the next slab.
SANDWICH = [0.08 + 0.12 * i for i in range(7)]
SEALED = 0.7        # share of samples sandwiched for the face to be invisible
# The measure is the largest UNBROKEN patch of bare surface, not the share of
# the face that is bare. Ribbing a ceiling at a 22-stud bay leaves 91 per cent
# of its area with nothing directly under it and yet reads as a modelled
# ceiling, because no one stretch of it is blank -- which is the whole point of
# a rib. A share test cannot tell a coffered ceiling from a slab; a flood fill
# over the bare samples can.
REPORT = 2400.0     # square studs in one unbroken bare patch
# A budget, not a zero. Some blank is right: the atrium's ceiling is broken by
# a forty-four stud skylight and two rows of roof lanterns, and a rib laid
# across those would be a rib laid across the only things up there. This is a
# ratchet -- it starts at what the map measures once the ceilings are ribbed,
# and comes down as the walls are dressed. It went in at 167,207.
BUDGET = 55000.0

# Ground and water are landscape, not surface: a lawn is meant to be empty, and
# so is a car park. Terrain has no parts anyway.
SKIP = ("Turf", "Grass", "Lawn", "Water", "Soil", "Tarmac", "Track", "Pitch",
        "Guard", "Emitter", "Collider", "Region", "Zone",
        # the pyramid is a cave cut out of rock and is meant to read as one;
        # tools/sanctum_check.py is what holds it to its own standard
        "Sanctum", "Cavern", "Tunnel", "Shaft",
        # Dressing is not a surface. A string course is a band standing off a
        # wall and the whole point of it is that it has nothing on it; the
        # library's and the staff lodge's came back as five-thousand-stud bare
        # "ceilings" because their undersides are exactly that.
        "Course", "Cornice", "Coping", "Band", "Sill", "Hood", "Plinth",
        "Kerb", "Verge", "Eaves", "Ridge", "Apron", "Step", "Tread", "Lap")


def rows(p):
    r = p["r"]
    return [(r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])]


def axis_aligned(p):
    """A signed permutation matrix, to within a rounding error."""
    for row in rows(p):
        big = [abs(v) for v in row]
        if abs(max(big) - 1.0) > 0.02 or sum(big) > 1.05:
            return False
    return True


def aabb(p):
    r, s, c = p["r"], p["s"], p["p"]
    half = [0.5 * sum(abs(r[i * 3 + j]) * s[j] for j in range(3)) for i in range(3)]
    return [c[i] - half[i] for i in range(3)], [c[i] + half[i] for i in range(3)]


def biggest_patch(bare, nu, nv):
    """The largest four-connected run of bare samples on one face."""
    seen = set()
    best = 0
    for cell in bare:
        if cell in seen:
            continue
        stack, size = [cell], 0
        seen.add(cell)
        while stack:
            a, b = stack.pop()
            size += 1
            for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = (a + da, b + db)
                if nb in bare and nb not in seen:
                    seen.add(nb)
                    stack.append(nb)
        best = max(best, size)
    return best


def main():
    parts = json.load(open(DUMP))
    boxes = []
    for p in parts:
        if p["t"] >= 0.95:
            continue
        lo, hi = aabb(p)
        boxes.append((lo, hi, p["n"]))

    # a uniform grid so the "is anything standing here" test is not O(n) per sample
    CELL = 24.0
    grid = defaultdict(list)
    for idx, (lo, hi, _n) in enumerate(boxes):
        for i in range(int(lo[0] // CELL), int(hi[0] // CELL) + 1):
            for k in range(int(lo[2] // CELL), int(hi[2] // CELL) + 1):
                grid[(i, k)].append(idx)

    def occupied(pt, skip):
        for idx in grid.get((int(pt[0] // CELL), int(pt[2] // CELL)), ()):
            if idx == skip:
                continue
            lo, hi = boxes[idx][0], boxes[idx][1]
            if all(lo[a] - 0.01 <= pt[a] <= hi[a] + 0.01 for a in range(3)):
                return True
        return False

    findings = []
    for idx, p in enumerate(parts):
        if p["t"] >= 0.95 or any(w in p["n"] for w in SKIP):
            continue
        if not axis_aligned(p):
            continue
        # Only boxes. A wedge's bounding box has two faces the wedge does not
        # have, and the first run reported the dorm range's roof slopes as bare
        # WALLS 13,000 studs across -- faces that do not exist.
        if p.get("cls", "Part") not in ("Part", "SpawnLocation") or p.get("sh", "Block") != "Block":
            continue
        if not (-8.0 < p["p"][1] < 90.0):
            continue
        c, s = p["p"], p["s"]
        # world half-extents, and which world axis each local axis became
        half = [0.0, 0.0, 0.0]
        for i in range(3):
            half[i] = 0.5 * sum(abs(p["r"][i * 3 + j]) * s[j] for j in range(3))
        for axis in range(3):
            u, v = [a for a in range(3) if a != axis]
            area = 4 * half[u] * half[v]
            if area < BIG:
                continue
            for sign in (-1, 1):
                face_y = c[1] + sign * half[1]
                # Nobody sees the underside of the ground or the top of a slab
                # that is buried under another one. The first run of this check
                # spent its whole top ten on the SOFFITS of the school's base
                # slab, the court paving, the car park and the front road --
                # eleven thousand to a hundred and eleven thousand square studs
                # each, every one of them underground.
                if axis == 1 and face_y < 1.0:
                    continue
                # and the sky is not a surface anybody dresses
                if axis == 1 and sign == 1 and face_y > 34:
                    continue
                # A FLOOR IS MEANT TO BE EMPTY. It is the surface people walk
                # on; a corridor deck with nothing standing on it is a corridor,
                # not a defect. The first run put the upper hallway's floor and
                # its soffit at the top of the list on equal terms.
                if axis == 1 and sign == 1:
                    continue
                total = dressed = sealed = 0
                bare = set()
                nu = max(2, int(2 * half[u] / STEP))
                nv = max(2, int(2 * half[v] / STEP))
                for i in range(nu):
                    for j in range(nv):
                        pt = [c[0], c[1], c[2]]
                        pt[u] = c[u] - half[u] + (i + 0.5) * (2 * half[u] / nu)
                        pt[v] = c[v] - half[v] + (j + 0.5) * (2 * half[v] / nv)
                        total += 1
                        near = False
                        for d in SANDWICH:
                            probe = list(pt)
                            probe[axis] = c[axis] + sign * (half[axis] + d)
                            if occupied(probe, idx):
                                near = True
                                break
                        if near:
                            sealed += 1
                            continue
                        hit = False
                        for d in RELIEF:
                            probe = list(pt)
                            probe[axis] = c[axis] + sign * (half[axis] + d)
                            if occupied(probe, idx):
                                hit = True
                                break
                        if hit:
                            dressed += 1
                        else:
                            bare.add((i, j))
                if not total or sealed / total > SEALED:
                    continue
                cell = (2 * half[u] / nu) * (2 * half[v] / nv)
                patch = biggest_patch(bare, nu, nv) * cell
                if patch >= REPORT:
                    face = "ceiling" if axis == 1 else "wall"
                    findings.append((patch, p["n"], face, [round(v) for v in c],
                                     round(100.0 * (total - sealed - dressed) / max(1, total - sealed))))
                    break

    findings.sort(reverse=True)
    total_blank = sum(f[0] for f in findings)
    print(f"{len(findings)} surfaces carry an unbroken bare patch over "
          f"{int(REPORT):,} square studs; {total_blank:,.0f} square studs of blank in total")
    for area, name, face, at, pct in findings[:18]:
        print(f"  {area:8,.0f} sq studs unbroken  ({pct:3d}% of the face bare)  "
              f"{face:7s} {name} at {at}")
    if total_blank > BUDGET:
        print(f"FAIL - {total_blank:,.0f} square studs of blank surface, over the "
              f"{int(BUDGET):,} budget")
        return 1
    print(f"PASS - blank surface is {total_blank:,.0f} square studs, "
          f"under the {int(BUDGET):,} budget")
    return 0


if __name__ == "__main__":
    sys.exit(main())
