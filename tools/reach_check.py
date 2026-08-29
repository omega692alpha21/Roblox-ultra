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
import json, math, os, re, sys
from collections import deque

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "..")
DUMP = os.path.join(HERE, "_map_export.json")

CELL = 1.0

# The grid is the PLOT, read from the drawing. It used to be a fixed 920 x 920
# square centred on the origin, drawn when the campus was that size. The plot
# is now 1640 x 1420 and reaches x = 840 and z = 780, so the gymnasium, the
# sports field, the car park and both reserves sat off the edge of the grid --
# every one of them read as "walled in" no matter what was built there, which
# is a checker that cannot fail usefully.
def _plot():
    src = open(os.path.join(REPO, "src/ReplicatedStorage/Shared/CampusPlan.luau")).read()
    m = re.search(r"Plan\.PLOT = \{ *([-\d.]+), *([-\d.]+), *([-\d.]+), *([-\d.]+) *\}", src)
    return [float(v) for v in m.groups()]


X0, Z0, X1, Z1 = _plot()
NX = int((X1 - X0) / CELL)
NZ = int((Z1 - Z0) / CELL)

# Terrain: MapService fills the whole plot with a grass slab just under y = 0.
TERRAIN_TOP = -0.1

STEP_UP = 3.0     # how far above the level a surface can be and still be floor
STEP_DOWN = 3.0
BODY_LOW = 0.6    # the band a body occupies above the floor
BODY_HIGH = 5.0


def gx(world):
    return int((world - X0) / CELL)


def gz(world):
    return int((world - Z0) / CELL)


def world_x(index):
    return index * CELL + X0 + CELL / 2


def world_z(index):
    return index * CELL + Z0 + CELL / 2


def cells_covering(lo, hi, origin, n):
    """[first, last) cell indices whose centre lies between lo and hi."""
    first = int(math.ceil((lo - origin - CELL / 2) / CELL))
    last = int(math.floor((hi - origin - CELL / 2) / CELL)) + 1
    return max(first, 0), min(last, n)


def aabb(part):
    r, s, p = part["r"], part["s"], part["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(p[i] - half[i], p[i] + half[i]) for i in range(3)]


# Doors that are shut on purpose. A homeroom gate opens when you claim the
# plot, so a reachability proof has to walk through it or every homeroom in
# the school reads as walled in.
# and the front doors, which are modelled swung open at 72 degrees. Every part
# here is tested as an axis-aligned box, so a leaf standing at an angle reads
# as a slab right across the opening it is standing clear of.
OPENABLE = ("Gate", "MainDoor", "MainDoorGlass")


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
    floor = np.full((NX, NZ), -1e9, dtype=np.float32)

    if level < 1:  # the ground storey sits on the terrain slab, which is the plot
        floor[:, :] = TERRAIN_TOP

    for part in parts:
        if not part.get("cc") or part["n"] in OPENABLE:
            continue
        box = aabb(part)
        # Cells whose CENTRE the box covers, not every cell it touches.
        # Touch-coverage inflates each box by up to a cell on all four sides,
        # which closed the five-stud aisle between the lab benches and left a
        # professor standing in an unreachable slot.
        x0, x1 = cells_covering(box[0][0], box[0][1], X0, NX)
        z0, z1 = cells_covering(box[2][0], box[2][1], Z0, NZ)
        if x1 <= x0 or z1 <= z0:
            continue
        top, bottom = box[1][1], box[1][0]
        boxes.append((x0, x1, z0, z1, bottom, top))
        if level - STEP_DOWN <= top <= level + STEP_UP:
            patch = floor[x0:x1, z0:z1]
            np.maximum(patch, top, out=patch)

    blocked = np.zeros((NX, NZ), dtype=bool)
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
        if 0 <= sx < NX and 0 <= sz < NZ and walkable[sx, sz] and not seen[sx, sz]:
            seen[sx, sz] = True
            queue.append((sx, sz))
    while queue:
        x, z = queue.popleft()
        here = floor[x, z]
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if 0 <= nx < NX and 0 <= nz < NZ and walkable[nx, nz] and not seen[nx, nz]:
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
    ("library", [-320, 0, -278]), ("cafeteria", [372, 0, -300]), ("principal office", [-196, 0, 46]),
    ("detention cell", [-438, 0, -14]), ("trophy room", [204, 0, -29]),
    ("greenhouse", [-116, 1, -28]), ("east lab", [116, 0, -28]),
    ("room 101", [-74, 0, -95]), ("music room", [74, 0, -95]),
    ("dorm lobby", [0, 0, -276]), ("dorm 1", [-114, 0, -344]),
    ("dorm 5", [-58, 0, -276]), ("dorm laundry", [114, 0, -276]),
    ("teachers quarters", [-300, 3, -170]),
    ("upper corridor", [0, 16, 65]),
]
for i, x in enumerate((-190, -122, 122, 190)):
    FIXED.append((f"homeroom south {i + 1}", [x, 0, 103]))
    FIXED.append((f"homeroom north {i + 1}", [x, 0, -94]))


# The four flights, by the cell at the bottom and the cell at the top.
STAIR_FEET = [("lobby west", -46, 114), ("lobby east", 46, 114),
              ("wing west", -178, -9), ("wing east", 178, -9)]
UPPER_HEADS = [("lobby east", 46, 88), ("wing west", -178, 17), ("wing east", 178, 17)]
SEED_HEAD = (-46, 88)  # the one flight the upper flood is allowed to start from

# The staff lodge's second flight, and what has to be reachable once you are up
# it: the desk on its dais, the fire, the long table, and the bookshelf that is
# a door. A grand room you cannot cross is not grand.
OFFICE_HEAD = (-270, -172)
OFFICE_SPOTS = [
    ("office desk", -278, -170),
    ("office fire", -306, -200),
    ("office table", -283, -170),
    ("office bookshelf wall", -262, -186),
]


def extra_targets():
    """Everywhere else the game asks a player or an NPC to be.

    Map anchors (collect pads, clique boards, the secret door), the waypoints
    the hallway crowd walks between, the professors, and the mission givers.
    A room you cannot enter is obvious once someone tries; a patrol waypoint
    inside a wall just makes the crowd behave strangely and nobody ever traces
    it back.
    """
    out = []
    anchors = os.path.join(HERE, "_map_anchors.json")
    if os.path.exists(anchors):
        for row in json.load(open(anchors)):
            # signs and boards hang on walls; the reach test in world_audit
            # covers those. Here we only want things at standing height.
            if row["p"][1] <= 8:
                out.append(("anchor " + row["k"][4:], row["p"]))

    npc = os.path.join(REPO, "src/ServerScriptService/Services/NPCDirector.luau")
    if os.path.exists(npc):
        text = open(npc).read()
        block = text[text.index("local POIS"):text.index("local AMBIENT_IDS")]
        for m in re.finditer(r"Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\),\s*--\s*(.+)", block):
            out.append(("waypoint " + m.group(4).strip(),
                        [float(m.group(1)), float(m.group(2)), float(m.group(3))]))

    subjects = os.path.join(REPO, "src/ReplicatedStorage/Config/Subjects.luau")
    if os.path.exists(subjects):
        text = open(subjects).read()
        for m in re.finditer(
            r'professor = "([^"]+)".*?position = Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)',
            text, re.S):
            out.append(("professor " + m.group(1),
                        [float(m.group(i)) for i in (2, 3, 4)]))

    missions = os.path.join(REPO, "src/ServerScriptService/Services/MissionService.luau")
    if os.path.exists(missions):
        text = open(missions).read()
        for m in re.finditer(
            r'name = "([^"]+)",\s*\n\s*baseId[^\n]*\n(?:[^\n]*\n)?\s*position = Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)',
            text):
            out.append(("giver " + m.group(1), [float(m.group(i)) for i in (2, 3, 4)]))
    return out


def main():
    parts = json.load(open(DUMP))
    targets = FIXED + rooms_from_source()
    spots = extra_targets()

    levels = {}
    for level in (0.0, 16.0, 35.0):
        walkable, floor = build_level(parts, level)
        levels[level] = (walkable, floor)

    # Start where a player actually starts -- the SpawnLocation, found in the
    # dump by name. This was a hard-coded strip up the entrance axis at x = 0,
    # z = 130..190, written when the spawn pad was there. The Great Court then
    # put a fountain on that line, so most of the seeds landed on the fountain
    # rim and the flood began three studs in the air inside a stone ring.
    ground_walkable, ground_floor = levels[0.0]
    pad = next((q for q in parts if q["n"] == "BusStop"), None)
    if pad is None:
        print("no SpawnLocation named BusStop in the dump")
        return 1
    pbox = aabb(pad)
    sx0, sx1 = cells_covering(pbox[0][0], pbox[0][1], X0, NX)
    sz0, sz1 = cells_covering(pbox[2][0], pbox[2][1], Z0, NZ)
    starts = [(x, z) for x in range(sx0, sx1) for z in range(sz0, sz1)]
    ground_seen = flood(ground_walkable, ground_floor, starts)
    if not ground_seen.any():
        print(f"the spawn pad at {[round(v, 1) for v in pad['p']]} has no standable floor")
        return 1

    bad = []

    # Every flight has to be walkable up to: check its foot from the ground.
    for name, sx, sz in STAIR_FEET:
        cx, cz = gx(sx), gz(sz)
        if not ground_seen[cx, cz]:
            bad.append((f"{name} stair foot", [sx, 0, sz], "cannot be walked to"))

    # Upstairs is a separate raster, so the flood cannot climb the stairs by
    # itself. Seed it from ONE stair head only -- deliberately. If the upper
    # floor is properly connected, one flight reaches all of it; seeding all
    # four would hide a landing that leads nowhere.
    upper_walkable, upper_floor = levels[16.0]
    upper_starts = []
    cx, cz = gx(SEED_HEAD[0]), gz(SEED_HEAD[1])
    for dx in range(-3, 4):
        for dz in range(-3, 4):
            x, z = cx + dx, cz + dz
            if 0 <= x < NX and 0 <= z < NZ and upper_walkable[x, z]:
                upper_starts.append((x, z))
    if not upper_starts:
        bad.append(("upper landing", list(SEED_HEAD), "the stair arrives nowhere standable"))
    upper_seen = flood(upper_walkable, upper_floor, upper_starts)

    # The headmaster's office: the whole top floor of the staff lodge, reached
    # by a second flight off the studies landing. Its own storey, so it needs
    # its own grid and its own seed at the head of that flight.
    office_walkable, office_floor = levels[35.0]
    office_starts = []
    ox, oz = gx(OFFICE_HEAD[0]), gz(OFFICE_HEAD[1])
    for dx in range(-6, 7):
        for dz in range(-6, 7):
            x, z = ox + dx, oz + dz
            if 0 <= x < NX and 0 <= z < NZ and office_walkable[x, z]:
                office_starts.append((x, z))
    if not office_starts:
        bad.append(("headmaster's stair", list(OFFICE_HEAD), "arrives nowhere standable"))
    office_seen = flood(office_walkable, office_floor, office_starts)
    for name, px, pz in OFFICE_SPOTS:
        cx, cz = gx(px), gz(pz)
        if not any(
            0 <= cx + dx < NX and 0 <= cz + dz < NZ and office_seen[cx + dx, cz + dz]
            for dx in range(-6, 7)
            for dz in range(-6, 7)
        ):
            bad.append((name, [px, 35, pz], "cut off inside the headmaster's office"))

    # and the other three heads have to be reachable across the upper floor
    for name, hx, hz in UPPER_HEADS:
        cx, cz = gx(hx), gz(hz)
        if not any(
            upper_seen[cx + dx, cz + dz]
            for dx in range(-6, 7)
            for dz in range(-6, 7)
        ):
            bad.append((f"{name} stair head", [hx, 16, hz], "cut off from the rest of the upper floor"))
    for name, point in targets:
        upstairs = point[1] > 8
        seen, walkable = (upper_seen, upper_walkable) if upstairs else (ground_seen, ground_walkable)
        cx, cz = gx(point[0]), gz(point[2])
        # Accept anywhere in a room-sized patch. A room centre very often
        # lands on the thing the room is for -- a grand piano, a lab bench, a
        # garden bed -- and calling that "unreachable" buries the real cases.
        # What matters is whether ANY floor in the room is standable, and
        # whether the flood from the front doors got to it.
        found = standable = False
        for dx in range(-20, 21, 2):
            for dz in range(-20, 21, 2):
                x, z = cx + dx, cz + dz
                if 0 <= x < NX and 0 <= z < NZ and walkable[x, z]:
                    standable = True
                    if seen[x, z]:
                        found = True
        if not standable:
            bad.append((name, point, "no standable floor anywhere in the room"))
        elif not found:
            bad.append((name, point, "walled in — no route from the front doors"))

    # Anchors, waypoints, professors and givers are points rather than rooms:
    # a tight patch, because "somewhere within twenty studs is fine" would let
    # a waypoint sit inside a wall next to an open corridor.
    for name, point in spots:
        upstairs = point[1] > 8
        seen, walkable = (upper_seen, upper_walkable) if upstairs else (ground_seen, ground_walkable)
        cx, cz = gx(point[0]), gz(point[2])
        if not any(
            0 <= cx + dx < NX and 0 <= cz + dz < NZ and seen[cx + dx, cz + dz]
            for dx in range(-6, 7)
            for dz in range(-6, 7)
        ):
            standable = any(
                0 <= cx + dx < NX and 0 <= cz + dz < NZ and walkable[cx + dx, cz + dz]
                for dx in range(-6, 7)
                for dz in range(-6, 7)
            )
            bad.append((name, point,
                        "walled in" if standable else "nothing standable within six studs"))

    for name, point, why in bad:
        print(f"  {name:30s} {[round(v, 1) for v in point]}  {why}")
    print(f"{'FAIL' if bad else 'PASS'} - {len(targets)} rooms, {len(spots)} anchors and 4 flights, "
          + (f"{len(bad)} unreachable" if bad else "every one reachable from the front doors"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
