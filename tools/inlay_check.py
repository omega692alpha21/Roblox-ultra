#!/usr/bin/env python3
"""Find floor markings that are not on the floor.

The atrium is chequered with seventy-two tiles. Its floor is SchoolBaseFloor1
and the top of that is at y -0.20; the tiles sat at 0.24, which is a third of a
stud clear of it -- seventy-two slabs hovering over the middle of the school,
in the room the game's front doors open into. The note in the code that put
them there had raised them FROM 0.11 to clear a z-fight, which lifted them off
the floor instead of layering them onto it.

solid_check could not see it. Its floating test walks collidable parts, and a
decorative inlay is CanCollide false -- the same blind spot that hid a whole
building's worth of buried dressing from it.

This asks one thing of every thin flat thing lying near the ground: is there a
surface under it, and is it touching. A marking bedded into its floor passes; a
marking hanging in the air over one does not.

    python3 tools/render_map.py .
    python3 tools/inlay_check.py
"""
import json, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

INLAY = ("Tile", "Stripe", "Line", "Marking", "Joint", "Inlay", "Paint",
         "Rondel", "Kerb", "Band")
# Things with those words in their names that are not floor inlays.
NOT = ("Ceiling", "Roof", "Wall", "Chimney", "Turret", "Quarters", "Plan",
       "Sky", "Pipe", "Lantern", "Sign", "Board", "Cage", "Rail", "Track",
       # a stripe down the side of the bus is livery, not a floor marking, and
       # the only thing under it is the bus's own wheel
       "Bus")
MAX_Y = 6.0          # an inlay lies near the ground
MAX_THICK = 1.2      # ... and is thin
GAP = 0.25           # how far it may sit off what is under it
CELL = 24.0


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(q[i] - half[i], q[i] + half[i]) for i in range(3)]


def main():
    parts = json.load(open(DUMP))
    boxes = [(p, aabb(p)) for p in parts]
    grid = defaultdict(list)
    for p, b in boxes:
        if b[1][1] - b[1][0] <= MAX_THICK:
            continue                     # a thin thing cannot be the ground
        for cx in range(int(b[0][0] // CELL), int(b[0][1] // CELL) + 1):
            for cz in range(int(b[2][0] // CELL), int(b[2][1] // CELL) + 1):
                grid[(cx, cz)].append((p, b))

    floating, measured = [], 0
    for p, b in boxes:
        n = p["n"]
        if any(w in n for w in NOT) or not any(w in n for w in INLAY):
            continue
        if b[1][1] - b[1][0] > MAX_THICK or b[1][0] > MAX_Y:
            continue
        measured += 1
        cx = (b[0][0] + b[0][1]) / 2
        cz = (b[2][0] + b[2][1]) / 2
        best = None
        for q, qb in grid.get((int(cx // CELL), int(cz // CELL)), ()):
            if q is p:
                continue
            if qb[0][1] <= b[0][0] or qb[0][0] >= b[0][1]:
                continue
            if qb[2][1] <= b[2][0] or qb[2][0] >= b[2][1]:
                continue
            top = qb[1][1]
            if top > b[1][0] + 0.05:
                continue                 # that one is above us, not under us
            if best is None or top > best[0]:
                best = (top, q["n"])
        if best is None:
            continue                     # nothing under it at all; terrain's job
        gap = b[1][0] - best[0]
        if gap > GAP:
            floating.append((gap, n, [round(v, 1) for v in p["p"]], best[1]))

    print(f"{measured} floor inlays measured against what is under them")
    if floating:
        floating.sort(reverse=True)
        seen, shown = set(), 0
        for gap, name, pos, under in floating:
            if name in seen and shown > 10:
                continue
            seen.add(name)
            shown += 1
            if shown <= 12:
                print(f"  {gap:5.2f} above {under:22} {name:22} at {pos}")
        print(f"FAIL - {len(floating)} inlays are floating over the surface they belong on")
        return 1
    print("PASS - every floor marking is bedded on what is under it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
