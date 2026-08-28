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
import json, math, os, re, sys

DUMP = sys.argv[1] if len(sys.argv) > 1 else "_map_export.json"
REPO = sys.argv[2] if len(sys.argv) > 2 else "."

parts = json.load(open(DUMP))
solids = [p for p in parts if p.get("cc")]


def local(part, point):
    """The point in the part's own frame, so rotated parts are handled."""
    r = part["r"]
    d = [point[i] - part["p"][i] for i in range(3)]
    return [sum(r[row * 3 + i] * d[i] for i in range(3)) for row in range(3)]


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
        q = local(part, point)
        s = part["s"]
        if abs(q[0]) > s[0] / 2 or abs(q[2]) > s[2] / 2:
            continue
        top = part["p"][1] + s[1] / 2  # axis-aligned enough for floors
        if point[1] + 1.5 >= top >= point[1] - reach:
            if best is None or top > best[0]:
                best = (top, part["n"])
    return best


def headroom(point, need=5.0):
    for part in solids:
        q = local(part, [point[0], point[1] + need / 2 + 1.0, point[2]])
        s = part["s"]
        if all(abs(q[i]) <= s[i] / 2 for i in range(3)):
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
        ("pool deck", -340, 0, 10),
        ("clique board row", -158, 0, -44),
    ]:
        spots.append((name, [x, y, z]))

    for i, x in enumerate((-190, -122, 122, 190)):
        spots.append((f"homeroom south {i + 1}", [x, 0, 103]))
        spots.append((f"homeroom north {i + 1}", [x, 0, -94]))
    return spots


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

    print(f"{'FAIL' if bad else 'PASS'} - {bad} bad spots")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
