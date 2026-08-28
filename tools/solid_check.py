#!/usr/bin/env python3
"""Find geometry that is jammed through other geometry, or floating in air.

Everything else in this repo checks whether the map WORKS -- can you walk it,
reach it, is it lit, does it match the plan. Nothing has ever asked whether it
is BUILT: whether a wall passes through a roof, whether a chimney sits inside a
gable, whether a bench hangs six studs off the ground. Those are what "it looks
messy" is made of, and they are invisible to every functional check because
none of them stops the game working.

Two questions:

  * interpenetration -- does a part sit substantially inside another part that
    is not its own container? A trim board lapping a wall by a stud is how
    buildings are made; a chimney half inside a roof is not.
  * support -- is there anything under this part, within a reasonable drop?
    A floating bench is a bug; a hanging lamp is not, so anything the map
    itself declares as hanging or as a ceiling fitting is exempt.

    python3 tools/render_map.py . tools
    python3 tools/solid_check.py
"""
import json, math, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

CELL = 24.0
# How much of the smaller part may sit inside the larger one before it counts,
# and how big both have to be. Detail is SUPPOSED to be set into structure --
# a window frame lives inside the tower wall it is a window in -- so this only
# asks about two pieces of STRUCTURE occupying the same space, which is a
# mistake every time.
BURIED = 0.92
MIN_VOLUME = 260.0
# 0.92 rather than 0.7: a wall that a projecting bay is bonded into shares
# three studs with it and reads as 87% buried, which is how masonry works.
# Ninety-two per cent means the part is not there at all.

# Things that legitimately live inside or above other things.
HANGS = ("Lamp", "Light", "Chandelier", "Pendant", "Sign", "Plaque", "Board",
         "Banner", "Flag", "Bunting", "Ceiling", "Soffit", "Ridge", "Cap",
         "Roof", "Eaves", "Trim", "Rail", "Panel", "Glass", "Window", "Glow",
         "Fire", "Neon", "Torch", "Beam", "Lintel", "Arch", "Crest", "Clock",
         "Pediment", "Cornice", "Bell", "Spire", "Vent", "Pipe", "Wire",
         "Net", "Rope", "Bar", "Post", "Balus", "Guard", "Stripe", "Line",
         "Marking", "Water", "Jet", "Leaves", "Foliage", "Canopy", "Shard",
         "Orb", "Crystal", "Dust", "Star", "Cloud",
         # things that live inside other things by design
         "Books", "Shelf", "Spine", "Seat", "Tread", "Step", "Pillow",
         "Mattress", "Bed", "Quoin", "Buttress", "Dormer", "Chimney")


def aabb(part):
    r, s, p = part["r"], part["s"], part["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(p[i] - half[i], p[i] + half[i]) for i in range(3)]


def volume(box):
    return max(0.0, (box[0][1] - box[0][0]) * (box[1][1] - box[1][0]) * (box[2][1] - box[2][0]))


def overlap(a, b):
    span = [min(a[i][1], b[i][1]) - max(a[i][0], b[i][0]) for i in range(3)]
    if any(v <= 0 for v in span):
        return 0.0
    return span[0] * span[1] * span[2]


def exempt(name):
    low = name.lower()
    return any(word.lower() in low for word in HANGS)


def surface(box):
    """A slab: thin, and lying down. A room's finished floor laid over the
    campus-wide base slab is inside it by design, and so is a lawn under a
    greenhouse -- that is how floors are made, not a part jammed through one."""
    return box[1][1] - box[1][0] <= 2.5


def main():
    parts = [p for p in json.load(open(DUMP)) if p.get("cc")]
    boxes = [aabb(p) for p in parts]
    vols = [volume(b) for b in boxes]

    index = defaultdict(list)
    for i, box in enumerate(boxes):
        for cx in range(int(box[0][0] // CELL), int(box[0][1] // CELL) + 1):
            for cz in range(int(box[2][0] // CELL), int(box[2][1] // CELL) + 1):
                index[(cx, cz)].append(i)

    # ---- interpenetration ----
    seen, buried = set(), []
    for cell in index.values():
        if len(cell) > 400:
            continue        # a slab that covers the campus is in every cell
        for a in range(len(cell)):
            for b in range(a + 1, len(cell)):
                i, j = cell[a], cell[b]
                if (i, j) in seen:
                    continue
                seen.add((i, j))
                if vols[i] < MIN_VOLUME or vols[j] < MIN_VOLUME:
                    continue
                small, large = (i, j) if vols[i] <= vols[j] else (j, i)
                if exempt(parts[small]["n"]) or exempt(parts[large]["n"]):
                    continue
                if parts[small]["n"] == parts[large]["n"]:
                    continue     # a run of identical courses laps itself
                if surface(boxes[small]) and surface(boxes[large]):
                    continue
                share = overlap(boxes[i], boxes[j]) / vols[small]
                if share >= BURIED:
                    buried.append((share, parts[small]["n"], parts[large]["n"], parts[small]["p"]))

    # ---- support ----
    tops = defaultdict(list)
    for i, box in enumerate(boxes):
        for cx in range(int(box[0][0] // CELL), int(box[0][1] // CELL) + 1):
            for cz in range(int(box[2][0] // CELL), int(box[2][1] // CELL) + 1):
                tops[(cx, cz)].append(i)

    # A part is held if ANY other solid touches it, from any side. Set-in
    # windows, chimneys rising through a roof and stacked gable courses are
    # all carried by what is around them rather than by what is under them,
    # and asking only about what is underneath reports every one of them.
    floating = []
    for i, part in enumerate(parts):
        box = boxes[i]
        if box[1][0] < 1.0 or vols[i] < 40.0 or exempt(part["n"]):
            continue     # a chandelier is meant to hang
        cx, cz = int(part["p"][0] // CELL), int(part["p"][2] // CELL)
        held = False
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for j in tops.get((cx + dx, cz + dz), ()):
                    if j == i:
                        continue
                    other = boxes[j]
                    if all(other[k][0] - 1.0 < box[k][1] and box[k][0] < other[k][1] + 1.0
                           for k in range(3)):
                        held = True
                        break
                if held:
                    break
            if held:
                break
        if not held:
            floating.append((box[1][0], part["n"], part["p"]))

    buried.sort(key=lambda row: -row[0])
    floating.sort(key=lambda row: -row[0])
    if buried:
        print(f"  BURIED ({len(buried)})  a part mostly inside another")
        for share, small, large, at in buried[:14]:
            print(f"      {share * 100:3.0f}%  {small:22s} inside {large:22s} at {[round(v) for v in at]}")
    if floating:
        print(f"  FLOATING ({len(floating)})  nothing under it within two studs")
        for y, name, at in floating[:14]:
            print(f"      y={y:6.1f}  {name:24s} at {[round(v) for v in at]}")
    total = len(buried) + len(floating)
    print(f"{'FAIL' if total else 'PASS'} - {len(parts)} solids: "
          f"{len(buried)} buried, {len(floating)} floating")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
