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
import json, re, math, os, re, sys

DUMP = sys.argv[1] if len(sys.argv) > 1 else "_map_export.json"
REPO = sys.argv[2] if len(sys.argv) > 2 else "."

parts = json.load(open(DUMP))
solids = [p for p in parts if p.get("cc")]


def load_props():
    """Furniture, as boxes, in the same shape as a part.

    Props are recorded as placement REQUESTS, not built parts, so they live in
    a second dump and until now no route, stair or spiral walk could see a
    single one of them. That is the whole of "random places with stuff sticking
    out" and "both stairs are blocked by something": the map audit was walking
    an empty school. A prop's request frame sits at the FOOT of the model (or
    its head, when it hangs), which is what PropService's standOn does, so the
    box has to be pushed half its height along the frame's up axis to become a
    centre.
    """
    props_path = os.path.join(os.path.dirname(DUMP) or ".", "_map_props.json")
    sizes_path = os.path.join(REPO, "src/ReplicatedStorage/Config/PropSizes.luau")
    if not (os.path.exists(props_path) and os.path.exists(sizes_path)):
        return []
    sizes = {}
    for m in re.finditer(r"(\w+) = Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)",
                         open(sizes_path).read()):
        sizes[m.group(1)] = [float(m.group(i)) for i in (2, 3, 4)]
    out = []
    for row in json.load(open(props_path)):
        size = sizes.get(row["k"])
        if size is None:
            continue
        scale = row.get("sc") or 1.0
        s = [v * scale for v in size]
        r = row["r"]
        up = [r[1], r[4], r[7]]           # the frame's own +Y in world
        edge = s[1] / 2 * (-1.0 if row.get("hang") else 1.0)
        centre = [row["p"][i] + up[i] * edge for i in range(3)]
        out.append({"n": "prop " + row["k"], "p": centre, "r": r, "s": s,
                    "cc": True, "prop": True})
    return out


props = load_props()
solids += props


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


def yaw_only(part):
    """True if the part is turned only about the vertical axis."""
    r = part["r"]
    return abs(r[1]) < 1e-6 and abs(r[4] - 1.0) < 1e-6 and abs(r[7]) < 1e-6


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



# A uniform grid over the map's footprint. Every check in this file asks "what
# is near this point", and with props folded in there are thousands of boxes;
# scanning all of them per sample turned a two-second audit into minutes. Each
# solid is filed into the cells its bounding box covers, so a query touches a
# few dozen candidates instead of the whole map.
CELL = 16.0


def _key(x, z):
    return (int(math.floor(x / CELL)), int(math.floor(z / CELL)))


def _build_index(boxes):
    index = {}
    for part in boxes:
        box = aabb(part)
        for cx in range(_key(box[0][0], 0)[0], _key(box[0][1], 0)[0] + 1):
            for cz in range(_key(0, box[2][0])[1], _key(0, box[2][1])[1] + 1):
                index.setdefault((cx, cz), []).append(part)
    return index


INDEX = _build_index(solids)


def near(point):
    return INDEX.get(_key(point[0], point[2]), ())


# MapService lays a 900 x 900 grass slab whose top sits just under y = 0.
# Terrain is not in the part dump, so the audit has to know about it or every
# outdoor spot reads as a hole.
TERRAIN_HALF = 700
TERRAIN_TOP = -0.1

# Where MapService carves the terrain back to air. A shaft driven through solid
# terrain is invisible in the part dump and impassable in the game, so the
# audit has to know about the holes as well as the slab.
CARVED = [
    (-226, -126, 226, 126),      # main building
    (-52, -148, 52, -122),       # gym protrusion
    (-150, -370, 150, -250),     # the boarding house, on its drawn ground
    (-368, -336, -272, -264),    # library, on its drawn ground
    (-348, -208, -252, -132),    # staff lodge
    (-263, -200, -235, -172),    # the turret
    (-422, -300, -364, -280),    # the library's passage
    (-433, -303, -407, -277),    # the library's shaft
    (-380, -44, -300, 4),        # the swimming pool's basin
]


def floor_under(point, reach=7.0):
    """Highest solid surface within `reach` below the point."""
    best = None
    carved = any(
        x0 <= point[0] <= x1 and z0 <= point[2] <= z1 for x0, z0, x1, z1 in CARVED
    )
    # The plot is a rectangle now, longer north-to-south than it is wide and
    # centred south of the origin, because the campus grew backwards.
    if (not carved and abs(point[0]) <= TERRAIN_HALF
            and -850 <= point[2] <= 650
            and point[1] + 1.5 >= TERRAIN_TOP >= point[1] - reach):
        best = (TERRAIN_TOP, "terrain")
    for part in near(point):
        # Footprint first. For a part that is only YAWED -- turned about the
        # vertical, which every tread on a spiral stair is -- the honest test
        # is its own local x/z, and its top is exact either way. Using the
        # world bounding box for those turns a ten-stud tread lying at forty
        # degrees into a fourteen-stud square, so a sample on one tread found
        # the tread two steps above it and the descent read as a staircase
        # full of drops. Anything stood on its end still uses the box, because
        # there the local half-sizes say nothing useful.
        box = aabb(part)
        if yaw_only(part):
            q = local(part, point)
            s = part["s"]
            # A hair of slack on the footprint. Two stair treads butt edge to
            # edge, and a sample landing exactly on the seam misses BOTH of
            # them by half a float, which reads as a missing tread in the
            # middle of a perfectly good flight.
            if abs(q[0]) > s[0] / 2 + 1e-3 or abs(q[2]) > s[2] / 2 + 1e-3:
                continue
        elif not (box[0][0] - 1e-3 <= point[0] <= box[0][1] + 1e-3
                  and box[2][0] - 1e-3 <= point[2] <= box[2][1] + 1e-3):
            continue
        top = box[1][1]
        if point[1] + 1.5 >= top >= point[1] - reach:
            if best is None or top > best[0]:
                best = (top, part["n"])
    return best


def headroom(point, need=5.0):
    """Is there room for a body standing with its FEET at `point`?

    The caller passes the surface, not a point half a stud above it: an R15
    character is a shade over five studs tall, and measuring from mid-shin made
    every five-and-a-half-stud ceiling in the school read as a head-banger.
    """
    # The ORIENTED test, not the bounding box. A long thin wall running
    # diagonally has a bounding box wide enough to swallow the corridor it is
    # the side of, so every sample down a diagonal tunnel read as blocked by
    # the tunnel's own wall. `floor_under` still uses the box, because there
    # the question is genuinely "what is the highest surface over this point".
    # The whole column, not one point at head height. A picture hung at chest
    # height, a bench, an open locker door -- none of them are at the top of a
    # player's body, and a single probe up there walks straight through all of
    # them. The samples start just above the feet so the floor itself is never
    # the thing that blocks you.
    for height in (0.8, 1.8, 2.8, need / 2 + 1.0, need):
        probe = [point[0], point[1] + height, point[2]]
        for part in near(probe):
            if inside(part, probe):
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
        ("teachers landing", -324, 19, -150),
        ("infirmary", 122, 17, -94),
        ("sanctum cupboard", -216, 0, 30),
        ("sanctum stair head", -216, 0, 22),
        ("cafeteria", 372, 0, -300),
        ("principal office", -204, 0, 46),
        ("assembly hall floor", 0, 0, -100),
        ("greenhouse", -116, 1, -28),
        ("east lab", 116, 0, -33.5),
        ("room 101", -74, 0, -95),
        ("music room", 74, 0, -95),
        ("library floor", -320, 0, -278),
        ("gymnasium floor", 425, 0, 437),
        ("onboarding hub", 0, 3, 70),
        ("mission npc lunch lady", -204, 0, 50),
        ("mission npc courtyard", 150, 0, 10),
        ("mission npc cafeteria", 280, 0, -280),
        ("detention cell", -438, 0, -14),
        # The boarding house is one range on the axis now, drawn at
        # (-150, -370) to (150, -250) with fourteen rooms over two storeys.
        # These four were the two blocks that used to stand at (+-176, -232).
        ("dorm lobby", 0, 2, -276),
        ("dorm 1", -114, 2, -344),
        ("dorm 5", -58, 2, -276),
        ("dorm upper landing", 0, 17, -276),
        ("dorm 7 upstairs", -114, 17, -344),
        ("dorm 13 upstairs", 58, 17, -276),
        ("tennis court", 340, 0, -20),
        ("pool deck", -340, 0, -50),
        ("clique board row", -158, 0, -44),
    ]:
        spots.append((name, [x, y, z]))

    for i, x in enumerate((-190, -122, 122, 190)):
        spots.append((f"homeroom south {i + 1}", [x, 0, 103]))
        spots.append((f"homeroom north {i + 1}", [x, 0, -94]))
    return spots


def _luau_vec3(source, name):
    m = re.search(r"local\s+" + name + r"\s*=\s*Vector3\.new\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)", source)
    if not m:
        raise SystemExit(f"world_audit: cannot find {name} in MapService")
    return tuple(float(g) for g in m.groups())


_HERE = os.path.dirname(os.path.abspath(__file__))
_MAP_SRC = open(os.path.join(os.path.dirname(_HERE), "src/ServerScriptService/Services/MapService.luau")).read()
_SANCTUM_ENTRANCE = _luau_vec3(_MAP_SRC, "SANCTUM_ENTRANCE")
_TURRET = _luau_vec3(_MAP_SRC, "TURRET")
# The tunnel leaves the turret shaft through whichever doorway faces the
# sanctum, and moving the library REVERSED that: the entrance used to be east
# of the turret and is now well to the west, so the mouth flipped to the other
# side of the shaft. Derive which side rather than typing a point that is only
# right until something moves.
_MOUTH_SIDE = -1.0 if _SANCTUM_ENTRANCE[0] < _TURRET[0] else 1.0
_HEAD_MOUTH = (_TURRET[0] + _MOUTH_SIDE * 13.0, _SANCTUM_ENTRANCE[1], _TURRET[2])


# Routes a player actually walks, sampled end to end. The "can't go upstairs"
# glitch was a 0.2-stud gap between the deck and the roof slabs -- invisible to
# a handful of spot checks, obvious the moment you sample the whole corridor.
WALKS = [
    # Corridor centrelines, not arbitrary lines: each one is the middle of a
    # floor slab that exists, so anything this reports is a real obstruction.
    # The main corridor now has a run of locker islands down its middle, so
    # the walkable lanes are either side of them rather than up the centreline.
    ("main hallway north lane", (-215, 0, 74), (215, 0, 74)),
    ("main hallway south lane", (-215, 0, 56), (215, 0, 56)),
    ("upper corridor", (-215, 16, 65), (215, 16, 65)),
    ("upper west wing", (-213, 16, -60), (-213, 16, 45)),
    ("upper east wing", (213, 16, -60), (213, 16, 45)),
    # the two ways down to the estate under the library
    # The tunnels themselves. The boulevard beyond them belongs to SanctumMap
    # and is proved by tools/sanctum_check.py, which reads a different dump.
    # END READ FROM SOURCE. This was the old SANCTUM_ENTRANCE typed in by hand,
    # and when the library moved -- taking the pyramid estate and the tunnel's
    # far end with it -- the audit went on walking a line the map no longer has
    # a tunnel under, and reported three bad spots in a tunnel that is fine.
    ("headmaster tunnel", _HEAD_MOUTH, _SANCTUM_ENTRANCE),
    # From the reading room, through the secret door, into the passage. The
    # shelf opens on four digits and used to open onto twenty-six studs of
    # solid west wall, so the walk starts INSIDE the library and crosses the
    # wall line.
    ("library secret door", (-358, 0, -290), (-376, 0, -290)),
    ("library passage", (-408, -16, -290), (-420, -16, -290)),
    ("lobby to atrium", (0, 0, 118), (0, 0, 20)),
    # The entrance hall, across as well as through. It is the first room
    # anybody sees and it had grown two life-size statues, three sofas and a
    # forest; these are the lines a player walks from the doors to each stair
    # and each side bay, and nothing may stand in them.
    ("lobby west aisle", (-36, 0, 121), (-36, 0, 100)),  # stops at the reception counter
    ("lobby east aisle", (36, 0, 121), (36, 0, 100)),
    ("lobby to stair W", (-46, 0, 121), (-46, 0, 113)),
    ("lobby to stair E", (46, 0, 121), (46, 0, 113)),
    ("atrium to assembly hall", (0, 0, 20), (0, 0, -98)),
    # The library is at (-320, -300) now, so the walk that used to run south
    # from the gym to its door does not exist. What replaces it is the walk
    # from the Academy's rear doors out onto the back lawn.
    ("academy rear to lawn", (0, 0, -152), (0, 0, -186)),
    ("library colonnade", (-311, 0, -254), (-311, 0, -272)),
    # The stairs, sampled as ramps. This is the check that would have caught
    # the gap between the upper deck and the roof slabs the first time.
    ("lobby stair W", (-46, 0.5, 114), (-46, 16, 88)),
    ("lobby stair E", (46, 0.5, 114), (46, 16, 88)),
    ("wing stair W", (-178, 0.5, -9), (-178, 16, 17)),
    ("wing stair E", (178, 0.5, -9), (178, 16, 17)),
]

# The two spiral descents, as (name, centre x, z, top y, bottom y, radius,
# start angle) -- the same numbers MapService builds them from. A helix cannot
# be sampled as a straight line, and these are now the only way down to the
# estate, so they get walked tread by tread.
SPIRALS = [
    ("headmaster spiral", -249, -186, 33.6, -119.5, 7.0, math.pi),
    ("library spiral", -420, -290, -17.4, -119.5, 6.5, 0.0),
]
# Every straight flight in the school, as (name, foot x/y/z, head x/y/z, half
# width). A flight is walked tread by tread like the spirals: the centreline
# routes cannot see a stair, because a stair is not level.
STAIRS = [
    ("lobby stair W", (-46, 0.5, 114), (-46, 16, 88), 5),
    ("lobby stair E", (46, 0.5, 114), (46, 16, 88), 5),
    ("wing stair W", (-178, 0.5, -9), (-178, 16, 17), 5),
    ("wing stair E", (178, 0.5, -9), (178, 16, 17), 5),
    ("lodge stair to studies", (-270, 3.5, -146), (-270, 19, -176.4), 4),
    ("lodge stair to office", (-270, 19.5, -140), (-270, 35, -170.4), 4),
    ("library steps down", (-369, 0, -290), (-408, -16, -290), 5),
    # The boarding house's stair is a half-turn: two flights round a landing
    # at y = 8, which is how CampusPlan draws it. Described as one straight run
    # from the foot to the head it reads as two eight-stud steps.
    ("dorm stair lower", (-20, 2, -266), (-4, 9, -266), 4),
    ("dorm stair upper", (-4, 9, -282), (-20, 16, -282), 4),
]

SPIRAL_RISE = 1.4
SPIRAL_PER_TURN = 24

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
            for part in near(point):
                # a door is meant to be shut; what matters is the hole behind it
                if part["n"].startswith("Secret"):
                    continue
                if inside(part, point, pad=-0.2):
                    problems.append((name, point, "inside " + part["n"]))
                    break
            blocked = headroom([point[0], under[0], point[2]])
            if blocked and not blocked.startswith("Secret"):
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
    for part in near(stand):
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


def walk_stairs():
    """Climb every flight. A route that is level cannot check a staircase, and
    a staircase with something standing on it is the single most reported kind
    of broken geometry in this map: the ceiling that used to sit two studs over
    the second tread, the tree growing through the lodge steps."""
    problems = []
    for name, foot, head, half in STAIRS:
        run = (head[0] - foot[0], head[2] - foot[2])
        length = math.hypot(*run) or 1.0
        across = (-run[1] / length, run[0] / length)
        span = math.dist(foot, head)
        steps = max(4, int(span / 1.6))
        previous = None
        for i in range(steps + 1):
            t = i / steps
            point = [foot[j] + (head[j] - foot[j]) * t for j in range(3)]
            under = floor_under([point[0], point[1] + 3.0, point[2]], reach=9.0)
            if under is None:
                problems.append((name, point, "no tread"))
                previous = None
                continue
            stand = [point[0], under[0], point[2]]
            # A body needs room above the tread AND either side of it, and the
            # samples have to be close enough together to catch a NARROW
            # obstruction: a framed picture a stud and a bit wide, hung at
            # chest height in the middle of the west lobby flight, slipped
            # between three probes three studs apart for four builds.
            #
            # "Either side" is ACROSS the flight, not along it. Stepping in x
            # is sideways only for a flight that runs in z; on the library's
            # steps, which run east, it walked into the next tread up and
            # reported the staircase as blocked by itself.
            for offset in (0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9):
                probe = [stand[0] + across[0] * half * offset, stand[1],
                         stand[2] + across[1] * half * offset]
                blocked = headroom(probe, need=5.0)
                if blocked and not any(k in blocked for k in ("Tread", "Step", "Stringer", "Rail", "Secret")):
                    problems.append((name, probe, "no headroom: " + blocked))
                    break
            if previous is not None and abs(under[0] - previous) > 2.4:
                problems.append((name, point, f"{abs(under[0] - previous):.1f}-stud step"))
            previous = under[0]
    return problems


def walk_spirals():
    """Tread by tread down each spiral: is every one solid, and is the next
    one a step rather than a drop?"""
    problems = []
    for name, cx, cz, top, bottom, radius, facing in SPIRALS:
        steps = max(4, int((top - bottom) / SPIRAL_RISE))
        previous = None
        for i in range(steps + 1):
            angle = facing + i * (math.pi * 2 / SPIRAL_PER_TURN)
            point = [cx + math.cos(angle) * radius, top - i * SPIRAL_RISE, cz + math.sin(angle) * radius]
            under = floor_under([point[0], point[1] + 2.0, point[2]], reach=6.0)
            if under is None:
                problems.append((name, point, f"no tread at step {i}"))
                previous = None
                continue
            stand = [point[0], under[0], point[2]]
            blocked = headroom(stand, need=4.0)
            if blocked and "Tread" not in blocked and "Newel" not in blocked:
                problems.append((name, point, "no headroom: " + blocked))
            if previous is not None and abs(under[0] - previous) > 2.2:
                problems.append((name, point, f"{abs(under[0] - previous):.1f}-stud drop to the next tread"))
            previous = under[0]
    return problems


def main():
    bad = 0
    for name, point in collect():
        problems = []
        for part in near(point):
            if inside(part, point, pad=-0.2):
                problems.append("inside " + part["n"])
                break
        under = floor_under(point)
        if under is None:
            problems.append("no floor under it")
        elif under[0] < point[1] - 5:
            problems.append(f"floor {point[1] - under[0]:.1f} studs below ({under[1]})")
        # stand on whatever is under the spot before asking about headroom, the
        # way the route walks do -- otherwise a greenhouse path a third of a
        # stud thick reads as a ceiling on the professor standing on it
        feet = [point[0], under[0] if under else point[1], point[2]]
        blocked = headroom(feet)
        if blocked and not (blocked.startswith("Stair") and "stair foot" in name):
            problems.append("no headroom: " + blocked)
        if problems:
            bad += 1
            print(f"  {name:26s} {[round(v, 1) for v in point]}  {'; '.join(problems)}")

    for name, point, why in audit_anchors():
        bad += 1
        print(f"  {name:34s} {[round(v, 1) for v in point]}  {why}")

    walked = walk_routes() + walk_stairs() + walk_spirals()
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
          f"({len(WALKS)} routes, {len(STAIRS)} stairs and {len(SPIRALS)} spirals walked, "
          f"{anchor_count} anchors checked for reach)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
