#!/usr/bin/env python3
"""Hold the BUILT map to the drawing.

plan_check.py proves the drawing is sound. Nothing until now proved the build
matched it, and the gap showed: standing at the main gate, on the ceremonial
axis, the school was completely hidden behind a wall of trees with a slab of
tarmac across the walk. The drawing forbids that -- Plan.APPROACH is reserved
-- but the drawing was only ever checked against itself.

    python3 tools/plan_export.py
    python3 tools/render_map.py . tools
    python3 tools/build_check.py
"""
import json, os, sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))

# Things that have no business on the walk up to the front doors. A hedge is
# fine; a wood is not. A bench is fine; a skip is not.
# Back-of-house. None of it belongs anywhere on the ceremonial walk, at any
# distance from the axis.
BLOCKERS = (
    "Parking", "Car", "Tarmac", "Asphalt",
    "Shed", "Skip", "Dumpster", "Compost", "Goal", "Hoop", "Bleacher", "Dugout",
    "Scoreboard", "TrackLane", "FieldTurf", "Bunting", "NetPost", "Crop",
)
# Planting is different. An avenue of trees DOWN an approach is what an
# approach is for -- the reference art is full of them. What is wrong is a wood
# growing ACROSS it, so these are judged against the sight corridor instead of
# the whole rect.
SCENERY = ("Tree", "Trunk", "Branch", "Leaves", "Foliage", "Canopy", "Boulder", "Rock")
BLOCKER_PROPS = ("Bin", "Dumpster", "Skip", "Shed", "Compost")
SCENERY_PROPS = ("Tree", "KTree", "KRock", "KStump", "KLog", "KBush")
# The sight line itself: stand at the gate and you must see the doors.
SIGHT_HALF = 44.0
SIGHT_MAX_HEIGHT = 11.0
SIGHT_ALLOW = ("Gate", "Pier", "Fountain", "Water", "Basin", "Lamp", "Monument",
               "Flag", "Crest", "Pennant",
               "Fingerpost", "Banner", "Railing", "Bollard", "Kerb", "Paving",
               "Path", "Walk", "Court", "Plaza", "Lawn", "Step", "Joint")


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    h = [0.5 * sum(abs(r[i * 3 + j]) * s[j] for j in range(3)) for i in range(3)]
    return [(q[i] - h[i], q[i] + h[i]) for i in range(3)]


def overlaps(b, rect):
    return b[0][0] < rect[2] and rect[0] < b[0][1] and b[2][0] < rect[3] and rect[1] < b[2][1]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    plan = json.load(open(os.path.join(HERE, "_campus_plan.json")))
    parts = json.load(open(os.path.join(out, "_map_export.json")))
    props = json.load(open(os.path.join(out, "_map_props.json")))
    bad, notes = [], []

    approach = plan["approach"]
    plot, core = plan["plot"], plan["core"]

    # ---- A. the expansion reserves stay clear ------------------------------
    # A STRUCTURE on reserved land is a fault -- it is the expansion room being
    # eaten. Woodland is not: a tree belt is cleared the day somebody builds
    # there, so it is reported and not failed.
    for r in plan["reserves"]:
        built, wild = Counter(), 0
        for p in parts:
            if not overlaps(aabb(p), r["rect"]):
                continue
            if any(w in p["n"] for w in SCENERY):
                wild += 1
            else:
                built[p["n"]] += 1
        if built:
            worst = ", ".join(f"{n} x {k}" for k, n in built.most_common(3))
            bad.append(("reserve", f"{sum(built.values())} built parts stand on {r['name']}: {worst}"))
        if wild:
            notes.append(f"{wild} trees and rocks stand on {r['name']} (cleared when it is built on)")

    # ---- B. nothing escapes the plot ---------------------------------------
    outside = [p for p in parts if not (plot[0] - 1 <= p["p"][0] <= plot[2] + 1
                                        and plot[1] - 1 <= p["p"][2] <= plot[3] + 1)]
    if outside:
        worst = Counter(p["n"] for p in outside).most_common(3)
        bad.append(("plot", f"{len(outside)} parts stand outside the plot "
                            f"({', '.join(n for n, _ in worst)})"))

    # ---- C. the ceremonial approach ----------------------------------------
    blocking = Counter()
    for p in parts:
        if not overlaps(aabb(p), approach):
            continue
        if any(w in p["n"] for w in BLOCKERS):
            blocking[p["n"]] += 1
    sight_rect = [-SIGHT_HALF, approach[1], SIGHT_HALF, approach[3]]
    for p in parts:
        if any(w in p["n"] for w in SCENERY) and overlaps(aabb(p), sight_rect):
            blocking[p["n"] + " (across the axis)"] += 1
    for kind, n in Counter(p["k"] for p in props
                           if approach[0] < p["p"][0] < approach[2]
                           and approach[1] < p["p"][2] < approach[3]).items():
        if any(w in kind for w in BLOCKER_PROPS):
            blocking[kind + " (prop)"] += n
    for p in props:
        if (any(w in p["k"] for w in SCENERY_PROPS)
                and -SIGHT_HALF < p["p"][0] < SIGHT_HALF
                and approach[1] < p["p"][2] < approach[3]):
            blocking[p["k"] + " (prop, across the axis)"] += 1
    for name, n in blocking.most_common(10):
        bad.append(("approach", f"{n} x {name} stands on the walk from the gate to the doors"))

    # ---- D. and you can actually SEE the doors from the gate ---------------
    # The corridor starts BEYOND the facade. The approach rect begins at the
    # building line, so measuring from there counted the school's own window
    # frames, arch voussoirs and spire as things blocking the view of itself.
    sight = [-SIGHT_HALF, approach[1] + 16, SIGHT_HALF, approach[3]]
    tall = Counter()
    for p in parts:
        b = aabb(p)
        if not overlaps(b, sight) or b[1][1] < SIGHT_MAX_HEIGHT:
            continue
        if any(w in p["n"] for w in SIGHT_ALLOW):
            continue
        tall[p["n"]] += 1
    for name, n in tall.most_common(8):
        bad.append(("sightline", f"{n} x {name} rises over {SIGHT_MAX_HEIGHT:.0f} studs on the axis"))

    # ---- E. every drawn building is actually there -------------------------
    for entry in plan["site"]:
        if entry["kind"] != "building":
            continue
        n = sum(1 for p in parts if overlaps(aabb(p), entry["rect"]))
        if n < 20:
            bad.append(("missing", f"{entry['name']} is drawn at {entry['rect']} and only "
                                   f"{n} parts stand there"))

    print(f"{len(parts)} parts, {len(props)} props measured against the drawing")
    if not bad:
        for note in notes:
            print(f"  (note) {note}")
        print("PASS - the build matches the drawing")
        return 0
    for note in notes:
        print(f"  (note) {note}")
    for where, why in bad:
        print(f"  [{where}] {why}")
    print(f"FAIL - {len(bad)} ways the build departs from the drawing")
    return 1


if __name__ == "__main__":
    sys.exit(main())
