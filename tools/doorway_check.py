#!/usr/bin/env python3
"""Find anything solid standing in a walkway.

MapService's geometry is generated, so a sign post planted in a doorway is
invisible in code review and obvious the moment someone tries to walk inside.
This walks the exported part dump and reports collidable parts whose CENTRE
sits in a lane a player has to pass through.

Centre, not overlap: a corridor's lockers line its walls and belong there, and
a door frame stands beside a door rather than in it. A part whose middle is in
the lane is in the way.

    python3 tools/render_map.py .      # regenerates _map_export.json
    python3 tools/doorway_check.py _map_export.json
"""
import json, sys

dump = sys.argv[1] if len(sys.argv) > 1 else "_map_export.json"
parts = json.load(open(dump))

# (name, cx, cy, cz, sx, sy, sz) - y spans 1..9, floor to head height
LANES = [
    ("main entrance",       0, 5,  100,  14, 8, 30),
    ("lobby into corridor", 0, 5,   79,  20, 8, 14),
    ("corridor into atrium",0, 5,   62,  20, 8, 14),
    ("main corridor",       0, 5,   70, 430, 8,  8),
    ("room 101 door",     -74, 5,  -64,  10, 8, 10),
    ("music room door",    74, 5,  -64,  10, 8, 10),
    # 10 deep: the clear gap between the door frames, which stand at +/-6.6
    ("cafeteria door",   -184, 5,  -23,  10, 8, 10),
    ("principal door",   -184, 5,   35,  10, 8, 10),
    ("trophy door",       184, 5,  -23,  10, 8, 10),
    ("detention door",    184, 5,   35,  10, 8, 10),
    ("gym mouth",           0, 5,  -64,  20, 8, 10),
    ("greenhouse door",  -116, 5,   -8,  24, 8, 10),
    ("east lab door",     116, 5,   -8,  24, 8, 10),
    ("library door",        0, 5, -198,  12, 8, 14),
]

# things that are meant to be stood around, not walked through
ALLOWED = ("Fountain", "Locker", "Bench", "Planter", "Tree", "Flower", "Hedge")


def world_extents(part):
    """Half-extents along the world axes, accounting for rotation.

    A rotated cylinder reports its Size along its own axes, so a standing
    column reads as a beam lying on its side unless the rotation is applied.
    """
    r = part.get("r")
    if not r or len(r) != 9:
        return [v / 2 for v in part["s"]]
    return [
        0.5 * sum(abs(r[row * 3 + col]) * part["s"][col] for col in range(3))
        for row in range(3)
    ]


def centre_in(part, lane):
    _, cx, cy, cz, sx, sy, sz = lane
    for i, (bc, bs) in enumerate(((cx, sx), (cy, sy), (cz, sz))):
        if abs(part["p"][i] - bc) >= bs / 2:
            return False
    return True


# A door that MOVES has to own every piece of itself.
#
# The secret bookshelf is a backing slab with four boards and thirty-two books
# on it. The boards and books were built as SIBLINGS of the slab, and only the
# slab was ever tweened: pulling the book slid a bare panel down the passage
# and left the shelf you were looking at hanging in the doorway. From the
# reading room that is a bookshelf that does not open, with a second bookshelf
# appearing behind it. Nothing in the geometry is wrong, which is why every
# walkway check passed while the door was unusable -- the only place the fault
# is visible is parentage.
MOVING = {"SecretShelf": "SecretBookshelf"}

bad = 0
for prefix, owner in MOVING.items():
    orphans = [p for p in parts
               if p["n"].startswith(prefix) and not p.get("par", "").startswith(owner)]
    if orphans:
        print(f"\n  {len(orphans)} {prefix}* part(s) are not children of a {owner}*")
        print(f"      they will be left behind when the door moves")
        for h in orphans[:4]:
            x, y, z = h["p"]
            print(f"      {h['n']:22s} at ({x:7.1f},{y:5.1f},{z:7.1f})  parent {h.get('par') or '(root)'}")
        bad += len(orphans)

for lane in LANES:
    hits = [p for p in parts
            if p.get("cc", True)
            and max(world_extents(p)) > 0.3
            and not any(a in p["n"] for a in ALLOWED)
            and centre_in(p, lane)]
    if hits:
        print(f"\n  {lane[0]}: {len(hits)} solid part(s) in the way")
        for h in sorted(hits, key=lambda p: p["n"])[:10]:
            x, y, z = h["p"]
            w, ht, d = (v * 2 for v in world_extents(h))
            print(f"      {h['n']:24s} at ({x:7.1f},{y:5.1f},{z:7.1f})  spans {w:.1f}x{ht:.1f}x{d:.1f}")
        bad += len(hits)

print("\nPASS - every walkway is clear" if bad == 0 else f"\nFAIL - {bad} obstruction(s)")
sys.exit(0 if bad == 0 else 1)
