"""Stand at every place the game sends a player and check the floor is there.

The bugs that have actually shipped in this map are all the same bug: a
coordinate written in a service that no longer matches the geometry a builder
produces. A professor standing inside a wall, a stair landing over a hole, an
NPC walking to a dorm that moved. None of them are visible in code review and
all of them are obvious the moment you stand on the spot.

So this stands on the spot. For every gameplay position it asks three
questions of the exported part dump:

  * is the point inside something solid?
  * is there a floor under it, within a step?
  * is there room to stand up?

    python3 tools/render_map.py .            # regenerates the dump
    python3 tools/world_audit.py <dump>
"""
import math
import json, math, os, re, sys

DUMP = sys.argv[1] if len(sys.argv) > 1 else "_map_export.json"
REPO = sys.argv[2] if len(sys.argv) > 2 else "."

parts = json.load(open(DUMP))
solids = [p for p in parts if p.get("cc")]


def local(part, point):
    """The point in the part's own frame, so rotated parts are handled.

    The export writes the rotation row-major as R, where a local offset maps
    to the world as R * v. Going the other way is R-transpose, so the local
    coordinate along axis `col` is column `col` dotted with the delta. This
    used to dot the ROWS, which is the inverse rotation applied backwards: for
    anything turned 90 degrees the axes came out swapped, and a trophy case
    forty studs away could read as the floor under your feet.
    """
    r = part["r"]
    d = [point[i] - part["p"][i] for i in range(3)]
    return [sum(r[row * 3 + col] * d[row] for row in range(3)) for col in range(3)]


def aabb(part):
    """World-space bounding box: half-extents of a rotated box on each axis."""
    r, s = part["r"], part["s"]
    half = [
        0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3))
        for row in range(3)
    ]
    return [(part["p"][i] - half[i], part["p"][i] + half[i]) for i in range(3)]


def inside(part, point, pad=0.0):
    q = local(part, point)
    s = part["s"]
    return all(abs(q[i]) <= s[i] / 2 + pad for i in range(3))


# MapService lays a 900 x 900 grass slab whose top sits just under y = 0.
# Terrain is not in the part dump, so the audit has to know about it or every
# outdoor spot reads as a hole.
TERRAIN_HALF = 450
TERRAIN_TOP = -0.1


def floor_under(point, reach=7.0):
    """Highest solid surface within `reach` below the point."""
    best = None
    if (abs(point[0]) <= TERRAIN_HALF and abs(point[2]) <= TERRAIN_HALF
            and point[1] + 1.5 >= TERRAIN_TOP >= point[1] - reach):
        best = (TERRAIN_TOP, "terrain")
    for part in solids:
        # a floor is whatever you would land on, so this is the world box --
        # local half-sizes say nothing useful about a part stood on its end
        box = aabb(part)
        if not (box[0][0] <= point[0] <= box[0][1] and box[2][0] <= point[2] <= box[2][1]):
            continue
        top = box[1][1]
        if point[1] + 1.5 >= top >= point[1] - reach:
            if best is None or top > best[0]:
                best = (top, part["n"])
    return best


def headroom(point, need=5.0):
    probe = [point[0], point[1] + need / 2 + 1.0, point[2]]
    for part in solids:
        box = aabb(part)
        if all(box[i][0] <= probe[i] <= box[i][1] for i in range(3)):
            return part["n"]
    return None


def luau_vectors(path, pattern):
    text = open(path).read()
    out = []
    for m in re.finditer(pattern, text):
        out.append((m.group(1), [float(m.group(i)) for i in (2, 3, 4)]))
    return out


def collect():
    spots = []
    subjects = os.path.join(REPO, "src/ReplicatedStorage/Config/Subjects.luau")
    if os.path.exists(subjects):
        text = open(subjects).read()
        for m in re.finditer(
            r'professor = "([^"]+)".*?position = Vector3%.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)'.replace("%", "\\"),
            text, re.S):
            spots.append(("professor " + m.group(1),
                          [float(m.group(2)), float(m.group(3)), float(m.group(4))]))

    npc = os.path.join(REPO, "src/ServerScriptService/Services/NPCDirector.luau")
    if os.path.exists(npc):
        text = open(npc).read()
        block = text[text.index("local POIS"):text.index("local AMBIENT_IDS")]
        for m in re.finditer(r"Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\),\s*--\s*(.+)", block):
            spots.append(("poi " + m.group(4).strip(),
                          [float(m.group(1)), float(m.group(2)), float(m.group(3))]))

    # the fixed places the game teleports to or builds around
    for name, x, y, z in [
        ("conveyor start", -190, 0, 65),
        ("conveyor end", 190, 0, 65),
        ("lobby doors", 0, 0, 118),
        ("atrium centre", 0, 0, 22),
        ("upper hall west", -150, 16, 65),
        ("upper hall east", 150, 16, 65),
        ("upper south rooms", -190, 16, 103),
        ("upper north rooms", 190, 16, -94),
        ("lobby stair foot W", -46, 0, 114),
        ("lobby stair head W", -46, 16, 88),
        ("lobby stair foot E", 46, 0, 114),
        ("lobby stair head E", 46, 16, 88),
        ("wing stair foot W", -178, 0, -9),
        ("wing stair head W", -178, 16, 17),
        ("wing stair foot E", 178, 0, -9),
        ("wing stair head E", 178, 16, 17),
        ("teachers common room", -300, 3, -170),
        ("teachers landing", -272, 19, -148),
        ("infirmary", 122, 17, -94),
        ("sanctum cupboard", -216, 0, 30),
        ("sanctum stair head", -216, 0, 22),
        ("cafeteria", -204, 0, -29),
        ("principal office", -196, 0, 46),
        ("gym floor", 0, 0, -100),
        ("greenhouse", -116, 1, -28),
        ("east lab", 116, 0, -28),
        ("room 101", -74, 0, -95),
        ("music room", 74, 0, -95),
        ("library floor", 0, 0, -210),
        ("onboarding hub", 0, 3, 70),
        ("mission npc lunch lady", -204, 0, 50),
        ("mission npc courtyard", 150, 0, 10),
        ("mission npc cafeteria", -204, 0, -6),
        ("detention cell", 204, 0, 35),
        ("dorm west", -176, 0, -212),
        ("dorm east", 176, 0, -212),
        ("tennis court", 340, 0, -20),
        ("pool deck", -340, 0, -20),
        ("clique board row", -158, 0, -44),
    ]:
        spots.append((name, [x, y, z]))

    for i, x in enumerate((-190, -122, 122, 190)):
        spots.append((f"homeroom south {i + 1}", [x, 0, 103]))
        spots.append((f"homeroom north {i + 1}", [x, 0, -94]))
    return spots


# Routes a player actually walks, sampled end to end. The "can't go upstairs"
# glitch was a 0.2-stud gap between the deck and the roof slabs -- invisible to
# a handful of spot checks, obvious the moment you sample the whole corridor.
WALKS = [
    # Corridor centrelines, not arbitrary lines: each one is the middle of a
    # floor slab that exists, so anything this reports is a real obstruction.
    ("main hallway", (-215, 0, 65), (215, 0, 65)),
    ("upper corridor", (-215, 16, 65), (215, 16, 65)),
    ("upper west wing", (-213, 16, -60), (-213, 16, 45)),
    ("upper east wing", (213, 16, -60), (213, 16, 45)),
    ("lobby to atrium", (0, 0, 118), (0, 0, 20)),
    ("atrium to gym", (0, 0, 20), (0, 0, -98)),
    ("gym to library path", (0, 0, -152), (0, 0, -186)),
    ("library colonnade", (9, 0, -186), (9, 0, -204)),
    # The stairs, sampled as ramps. This is the check that would have caught
    # the gap between the upper deck and the roof slabs the first time.
    ("lobby stair W", (-46, 0.5, 114), (-46, 16, 88)),
    ("lobby stair E", (46, 0.5, 114), (46, 16, 88)),
    ("wing stair W", (-178, 0.5, -9), (-178, 16, 17)),
    ("wing stair E", (178, 0.5, -9), (178, 16, 17)),
]

STEP = 4.0        # sample spacing, studs
MAX_RISE = 3.0    # a Humanoid steps 2.0 by default; 3 is generous


def walk_routes():
    """Sample every route end to end and report holes, steps and low ceilings.

    A route is a line, and a staircase is not: sampling every four studs the
    straight line lags the treads by up to a couple of studs either way. So
    each sample looks for the floor in a window around its nominal height and
    then STANDS ON IT before the clearance checks, which is what a player
    does. Without that every flight reads as a hole and a wall of its own
    treads, and the real problems are lost in the noise.
    """
    problems = []
    for name, a, b in WALKS:
        span = math.dist(a, b)
        steps = max(2, int(span / STEP) + 1)
        previous = None
        for i in range(steps):
            t = i / (steps - 1)
            point = [a[j] + (b[j] - a[j]) * t for j in range(3)]
            under = floor_under([point[0], point[1] + 3.0, point[2]], reach=12.0)
            if under is None:
                problems.append((name, point, "no floor"))
                previous = None
                continue
            point[1] = under[0] + 0.5
            for part in solids:
                if inside(part, point, pad=-0.2):
                    problems.append((name, point, "inside " + part["n"]))
                    break
            blocked = headroom(point)
            if blocked:
                problems.append((name, point, "no headroom: " + blocked))
            if previous is not None and abs(under[0] - previous) > MAX_RISE:
                problems.append((
                    name, point,
                    f"{abs(under[0] - previous):.1f}-stud step onto {under[1]}",
                ))
            previous = under[0]
    return problems


ANCHORS = os.path.join(os.path.dirname(DUMP) or ".", "_map_anchors.json")


def standable(point, reach=9.0):
    """Could a player stand here: floor within `reach` below, and room for a body.

    `reach` is deep when the caller is a wall-mounted anchor: a notice board at
    head height is reached from the floor seven studs under it, and searching
    only a step down finds nothing and calls a perfectly good board unreachable.
    """
    under = floor_under([point[0], point[1] + 3.0, point[2]], reach=reach)
    if under is None:
        return False
    stand = [point[0], under[0] + 0.5, point[2]]
    for part in solids:
        box = aabb(part)
        # a body is about five studs of head-height above the feet
        if (box[0][0] <= stand[0] <= box[0][1] and box[2][0] <= stand[2] <= box[2][1]
                and box[1][0] < stand[1] + 4.5 and box[1][1] > stand[1] + 0.4):
            return False
    return True


def reachable(point, radius=13.0):
    """Is there anywhere within prompt range you could stand and use this?

    Anchors are the things the game asks you to walk up to -- a collect pad, a
    clique board, the secret door. Several are mounted high on a wall, so the
    question is never "is the anchor standable" but "can a player get within
    reach of it". Sixteen bearings at three distances is enough to find a spot
    if one exists and cheap enough to run over every anchor in the map.
    """
    for ring in (radius * 0.45, radius * 0.7, radius * 0.95):
        for i in range(16):
            angle = i * math.pi / 8
            probe = [
                point[0] + math.cos(angle) * ring,
                point[1],
                point[2] + math.sin(angle) * ring,
            ]
            if standable(probe, reach=24.0):
                return True
    return False


def audit_anchors():
    """Every named place the map hands a service: can you get to it?"""
    if not os.path.exists(ANCHORS):
        return []
    problems = []
    for row in json.load(open(ANCHORS)):
        if not reachable(row["p"]):
            problems.append((row["k"], row["p"], "nothing within reach of it is standable"))
    return problems


def main():
    bad = 0
    for name, point in collect():
        problems = []
        for part in solids:
            if inside(part, point, pad=-0.2):
                problems.append("inside " + part["n"])
                break
        under = floor_under(point)
        if under is None:
            problems.append("no floor under it")
        elif under[0] < point[1] - 5:
            problems.append(f"floor {point[1] - under[0]:.1f} studs below ({under[1]})")
        blocked = headroom(point)
        if blocked:
            problems.append("no headroom: " + blocked)
        if problems:
            bad += 1
            print(f"  {name:26s} {[round(v, 1) for v in point]}  {'; '.join(problems)}")

    for name, point, why in audit_anchors():
        bad += 1
        print(f"  {name:34s} {[round(v, 1) for v in point]}  {why}")

    walked = walk_routes()
    # one line per route rather than per sample: a broken slab trips fifty
    # consecutive samples and the list stops being readable
    seen = set()
    for name, point, why in walked:
        key = (name, why.split(" onto ")[0])
        if key in seen:
            continue
        seen.add(key)
        bad += 1
        print(f"  {name:26s} {[round(v, 1) for v in point]}  {why}")

    anchor_count = len(json.load(open(ANCHORS))) if os.path.exists(ANCHORS) else 0
    print(f"{'FAIL' if bad else 'PASS'} - {bad} bad spots "
          f"({len(WALKS)} routes walked at {STEP:.0f}-stud spacing, "
          f"{anchor_count} anchors checked for reach)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
