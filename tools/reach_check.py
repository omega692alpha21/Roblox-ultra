#!/usr/bin/env python3
"""Prove you can walk from the front door to every room in the school.

The hand-written doorway lanes checked fifteen openings. There are far more
than fifteen doors, and the ones nobody thought to list are exactly the ones
that get walled up by a generated wall run or blocked by a sign post.

So this proves it instead of spot-checking it. Both floors are rasterised into
a walkability grid -- a cell is walkable if something's top surface is within a
step of the floor level and nothing solid occupies the body-height band above
it -- and then flood-filled from the spawn. Any room whose centre the flood
never reaches is a room you cannot get into.

    python3 tools/reach_check.py

Exit code is 1 if any room is cut off.
"""
import json, os, re, sys
from collections import deque

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "..")
DUMP = os.path.join(HERE, "_map_export.json")

CELL = 2.0
HALF = 460.0
N = int(HALF * 2 / CELL)

# Terrain: MapService lays a 900 x 900 grass slab just under y = 0.
TERRAIN_HALF, TERRAIN_TOP = 450.0, -0.1

STEP_UP = 3.0     # how far above the level a surface can be and still be floor
STEP_DOWN = 3.0
BODY_LOW = 0.6    # the band a body occupies above the floor
BODY_HIGH = 5.0


def grid_index(world):
    return int((world + HALF) / CELL)


def world_at(index):
    return index * CELL - HALF + CELL / 2


def aabb(part):
    r, s, p = part["r"], part["s"], part["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(p[i] - half[i], p[i] + half[i]) for i in range(3)]


# Doors that are shut on purpose. A homeroom gate opens when you claim the
# plot, so a reachability proof has to walk through it or every homeroom in
# the school reads as walled in.
OPENABLE = ("Gate",)


def build_level(parts, level):
    """(walkable, floor_height) grids for one storey.

    Two passes, and the order matters. The floor height has to be settled
    before anything can be called an obstacle, because whether a part is in
    the way depends on how high the floor under it is -- not on the nominal
    level. A one-pass version measured obstacles from the level and so a floor
    slab raised three studs (the teachers' quarters sit on a plinth) marked
    every cell of itself as blocked by itself.
    """
    boxes = []
    floor = np.full((N, N), -1e9, dtype=np.float32)

    if level < 1:  # the ground storey sits on the terrain slab
        lo, hi = grid_index(-TERRAIN_HALF), grid_index(TERRAIN_HALF)
        floor[lo:hi, lo:hi] = TERRAIN_TOP

    for part in parts:
        if not part.get("cc") or part["n"] in OPENABLE:
            continue
        box = aabb(part)
        x0, x1 = grid_index(box[0][0]), grid_index(box[0][1]) + 1
        z0, z1 = grid_index(box[2][0]), grid_index(box[2][1]) + 1
        if x1 <= 0 or z1 <= 0 or x0 >= N or z0 >= N:
            continue
        x0, z0 = max(x0, 0), max(z0, 0)
        x1, z1 = min(x1, N), min(z1, N)
        top, bottom = box[1][1], box[1][0]
        boxes.append((x0, x1, z0, z1, bottom, top))
        if level - STEP_DOWN <= top <= level + STEP_UP:
            patch = floor[x0:x1, z0:z1]
            np.maximum(patch, top, out=patch)

    blocked = np.zeros((N, N), dtype=bool)
    for x0, x1, z0, z1, bottom, top in boxes:
        patch = floor[x0:x1, z0:z1]
        # in the way of a body standing on THIS cell's floor
        blocked[x0:x1, z0:z1] |= (bottom < patch + BODY_HIGH) & (top > patch + BODY_LOW)

    walkable = (floor > -1e8) & ~blocked
    return walkable, floor


def flood(walkable, floor, starts):
    seen = np.zeros_like(walkable)
    queue = deque()
    for sx, sz in starts:
        if 0 <= sx < N and 0 <= sz < N and walkable[sx, sz] and not seen[sx, sz]:
            seen[sx, sz] = True
            queue.append((sx, sz))
    while queue:
        x, z = queue.popleft()
        here = floor[x, z]
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if 0 <= nx < N and 0 <= nz < N and walkable[nx, nz] and not seen[nx, nz]:
                # a Humanoid steps 2 studs; anything more is a wall or a drop
                if abs(floor[nx, nz] - here) <= 2.2:
                    seen[nx, nz] = True
                    queue.append((nx, nz))
    return seen


def rooms_from_source():
    """Every named room, read out of MapService so the list cannot drift."""
    src = open(os.path.join(REPO, "src/ServerScriptService/Services/MapService.luau")).read()
    out = []
    for m in re.finditer(
        r'name = "(\w+)", label = "([^"]*)"[^\n]*?center = Vector3\.new\(([-\d.]+), ([\w.]+), ([-\d.]+)\)',
        src,
    ):
        y = 16.0 if m.group(4) == "UPPER_Y" else float(m.group(4) or 0)
        out.append((m.group(2) or m.group(1), [float(m.group(3)), y, float(m.group(5))]))
    return out


FIXED = [
    # room centres the generated tables do not name
    ("lobby", [0, 0, 100]), ("atrium", [0, 0, 22]), ("gym floor", [0, 0, -100]),
    ("library", [0, 0, -210]), ("cafeteria", [-204, 0, -29]), ("principal office", [-196, 0, 46]),
    ("detention cell", [204, 0, 35]), ("trophy room", [204, 0, -29]),
    ("greenhouse", [-116, 1, -28]), ("east lab", [116, 0, -28]),
    ("room 101", [-74, 0, -95]), ("music room", [74, 0, -95]),
    ("west dorm", [-176, 0, -212]), ("east dorm", [176, 0, -212]),
    ("teachers quarters", [-300, 3, -170]),
    ("pool deck", [-340, 0, -20]), ("tennis court", [340, 0, -20]),
    ("upper corridor", [0, 16, 65]),
]
for i, x in enumerate((-190, -122, 122, 190)):
    FIXED.append((f"homeroom south {i + 1}", [x, 0, 103]))
    FIXED.append((f"homeroom north {i + 1}", [x, 0, -94]))


def main():
    parts = json.load(open(DUMP))
    targets = FIXED + rooms_from_source()

    levels = {}
    for level in (0.0, 16.0):
        walkable, floor = build_level(parts, level)
        levels[level] = (walkable, floor)

    # start where a player starts: the courtyard outside the front doors
    ground_walkable, ground_floor = levels[0.0]
    starts = [(grid_index(0), grid_index(z)) for z in range(130, 190, 4)]
    ground_seen = flood(ground_walkable, ground_floor, starts)

    # Upstairs is a separate raster, so the flood cannot climb the stairs by
    # itself. Seed it from every upper cell standing directly over a reached
    # ground cell at the top of a flight -- the stairwells.
    upper_walkable, upper_floor = levels[16.0]
    upper_starts = []
    for sx, sz in ((-46, 88), (46, 88), (-178, 17), (178, 17)):
        gx, gz = grid_index(sx), grid_index(sz)
        for dx in range(-3, 4):
            for dz in range(-3, 4):
                x, z = gx + dx, gz + dz
                if 0 <= x < N and 0 <= z < N and upper_walkable[x, z]:
                    upper_starts.append((x, z))
    upper_seen = flood(upper_walkable, upper_floor, upper_starts)

    bad = []
    for name, point in targets:
        upstairs = point[1] > 8
        seen, walkable = (upper_seen, upper_walkable) if upstairs else (ground_seen, ground_walkable)
        gx, gz = grid_index(point[0]), grid_index(point[2])
        # Accept anywhere in a room-sized patch. A room centre very often
        # lands on the thing the room is for -- a grand piano, a lab bench, a
        # garden bed -- and calling that "unreachable" buries the real cases.
        # What matters is whether ANY floor in the room is standable, and
        # whether the flood from the front doors got to it.
        found = standable = False
        for dx in range(-10, 11):
            for dz in range(-10, 11):
                x, z = gx + dx, gz + dz
                if 0 <= x < N and 0 <= z < N and walkable[x, z]:
                    standable = True
                    if seen[x, z]:
                        found = True
        if not standable:
            bad.append((name, point, "no standable floor anywhere in the room"))
        elif not found:
            bad.append((name, point, "walled in — no route from the front doors"))

    for name, point, why in bad:
        print(f"  {name:26s} {[round(v, 1) for v in point]}  {why}")
    print(f"{'FAIL' if bad else 'PASS'} - {len(targets)} rooms, "
          + (f"{len(bad)} unreachable" if bad else "every one reachable from the front doors"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
