"""THE PLAN. What is where at Crumbworth High, as data rather than as habit.

Every coordinate in MapService was chosen in isolation, months apart, by
whoever was adding that feature. Nothing has ever held them to a layout, so
the school grew the way a house grows when nobody draws it first: a sports
court in a light well, a glasshouse in a quadrangle, a bank of lockers in
front of the principal's door, and two signs pointing at each other's rooms.

This is the drawing. It is deliberately small -- a room schedule and a set of
rules -- because its whole value is that it is the ONE place the layout lives,
and tools/plan_check.py holds the built map to it.

Axes: +x east, +z north, y up. The front doors face north, onto the road.
"""

# ---------------------------------------------------------------------------
# THE SITE
# ---------------------------------------------------------------------------
# The main block is a double quadrangle: a solid outer rectangle of building
# with two open-air courtyards punched through it. Everything else on the
# campus is a detached outbuilding standing on the grounds.

ENVELOPE = (-224, -124, 224, 124)     # the main block's outer footprint
GROUND_Y, UPPER_Y, ROOF_Y = 0.0, 16.0, 33.2

# ---------------------------------------------------------------------------
# THE ROOM SCHEDULE
# ---------------------------------------------------------------------------
# name -> rect (x0, z0, x1, z1), storey, kind
#
#   kind "room"      a walled space you go into, reached from a corridor
#   kind "corridor"  a space you go THROUGH; its middle stays clear
#   kind "court"     open to the sky, inside the envelope
#   kind "outbuilding"  detached, on the grounds
#   kind "grounds"   open ground outside the envelope
ROOMS = [
    # ---- ground floor, main block --------------------------------------
    # Taken from the floor slabs the map actually lays, not from memory: the
    # wings run z -52..61 front to back with a double door at each END, and
    # the hallway runs BETWEEN them, which is why it stops at x = +-184.
    ("Entrance hall",      (-62,   84,   62,  124), 0, "room"),
    ("Main hallway",       (-184,  49,  184,   81), 0, "corridor"),
    ("Atrium",             (-60,    0,   60,   48), 0, "room"),
    ("Gym approach",       (-60,  -60,   60,    0), 0, "corridor"),
    ("Principal's office", (-224,   6, -184,   61), 0, "room"),
    ("Cafeteria",          (-224, -52, -184,    4), 0, "room"),
    ("Detention",          (184,    6,  224,   61), 0, "room"),
    ("Trophy hall",        (184,  -52,  224,    4), 0, "room"),
    ("Gym",                (-50, -146,   50,  -64), 0, "room"),
    ("Room 101",           (-88, -124,  -60,  -64), 0, "room"),
    ("Music room",         (60,  -124,   88,  -64), 0, "room"),
    ("West homerooms N",   (-221,  82, -91,   123), 0, "room"),
    ("East homerooms N",   (91,    82,  221,  123), 0, "room"),
    ("West homerooms S",   (-221,-114,  -91,  -70), 0, "room"),
    ("East homerooms S",   (91, -114,   221,  -70), 0, "room"),
    # ---- the two quadrangles: OPEN TO THE SKY ---------------------------
    ("West quad",          (-172, -52,  -60,   48), 0, "court"),
    ("East quad",          (60,   -52,  172,   48), 0, "court"),
    # ---- upper floor ----------------------------------------------------
    ("Upper corridor",     (-184,  49,  184,   81), 1, "corridor"),
    ("Upper south rooms",  (-224,  82,  224,  124), 1, "room"),
    ("Upper west wing",    (-224, -64, -184,   48), 1, "room"),
    ("Upper east wing",    (184,  -64,  224,   48), 1, "room"),
    ("Upper north rooms",  (-224,-124,  224,  -64), 1, "room"),
]

# Detached, on the grounds. Nothing in the envelope may claim these names.
OUTBUILDINGS = [
    ("Library",           (-46,  -266,   46, -198)),
    ("West dorm",         (-208, -239, -144, -185)),
    ("East dorm",         (144,  -239,  208, -185)),
    ("Teachers' quarters",(-346, -206, -254, -134)),
    ("Swimming pool",     (-400,  -64, -280,   24)),
    ("Tennis stadium",    (280,   -64,  400,   24)),
    # sport belongs OUT here, on the field, not in a light well
    ("North sports field",(-150,  132,  150,  200)),
]

# ---------------------------------------------------------------------------
# THE RULES
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# THE FRONT
# ---------------------------------------------------------------------------
# North is the front. The doors, the drive, the clock tower, the steps and the
# statue all face that way, and it is the first thing anybody sees when they
# join. It is a ceremonial approach: lawn, trees, hedge, benches, the drive and
# the school's own name.
#
# It is not where the sport goes, and it is not where the bins go. I put two
# painted courts and three runs of bunting on it when I took them out of the
# quadrangles, because "the north field" sounded like the back of the school
# and I never checked which way the building faced. This rule is here so that
# cannot happen twice.
FRONT_APPROACH = (-280, 124, 280, 330)

BACK_OF_HOUSE = (
    "CourtLine", "CourtRing", "CourtFloor", "BasketHoop", "Bunting", "Goal",
    "TrackLane", "StandTier", "StandSeat",
    "Shed", "GardenBed", "GardenCrop", "Compost", "Skip", "Dumpster",
    "Scoreboard", "Dugout", "Bleacher", "FieldTurf",
)
# A bench on the approach is right and so is a bike rack; a grandstand and a
# basketball hoop are not. Names have to be specific enough to tell those
# apart -- StandSeat not Seat, CourtLine not Court, BasketHoop not Hoop.

# Names that may only ever appear where there is sky above them. A tree in a
# lobby and a volleyball net under a roof are the same mistake.
OUTDOOR_ONLY = (
    "Tree", "Shrub", "Hedge", "Bunting", "Picnic", "Lawn", "Fence",
    "CourtLine", "CourtRing", "Net", "Rock", "Bus", "Car", "Road",
)

# A corridor is for walking down. Anything solid in its middle lane is an
# obstruction however good it looks: the reference photograph that justified
# freestanding locker islands was a corridor twice this one's width.
CORRIDOR_CLEAR_HALF = 7.0        # studs either side of the centreline

# Every door sign must name the room it hangs at. `at` is where the sign is;
# the room named must be the one whose rect contains the point one door-depth
# INSIDE the wall the sign is on.
DOOR_SIGN_DEPTH = 14.0

# Doorways: (name, x, y, z, width, height, depth) -- the lane a player walks
# through to get into a room. Nothing solid may stand in one, and no prop may
# stand within this box.
# The THRESHOLD only -- the few studs you actually pass through -- not the
# room beyond it. A lane cut deep enough to reach the desk reports the desk.
DOORWAYS = [
    # The THRESHOLD only -- the few studs you actually pass through -- not the
    # room beyond it. A lane cut deep enough to reach the desk reports the desk.
    ("principal's office door", -204, 5.5,  61, 11, 10, 8),
    ("cafeteria door",          -204, 5.5, -49, 11, 10, 8),
    ("detention door",           204, 5.5,  61, 11, 10, 8),
    ("trophy hall door",         204, 5.5, -49, 11, 10, 8),
    ("gym door",                   0, 5.5, -68, 18, 10, 8),
    ("room 101 door",            -74, 5.5, -64, 10, 10, 8),
    ("music room door",           74, 5.5, -64, 10, 10, 8),
]


def room_at(x, z, storey=0):
    """The room whose rect contains this point, or None."""
    for name, (x0, z0, x1, z1), level, kind in ROOMS:
        if level == storey and x0 <= x <= x1 and z0 <= z <= z1:
            return name, kind
    return None
