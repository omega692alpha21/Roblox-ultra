#!/usr/bin/env python3
"""Find windows that are not windows.

The four reference images are night pictures, and the one thing they all have
in common is that every window in them is lit warm gold. A window that is not
lit is not a small defect in a night scene -- it is the difference between a
school at night and a grey block after dark.

Nothing checked it, and the cost of that was 264 windows: every opening on all
three storeys of the Academy, which is the elevation the whole game opens on.
They were built as SmoothPlastic panes with Reflectance, and MapService's
litWindows pass -- which walks the map putting a neon leaf inside every pane --
only looks at parts whose Material is Glass. So it skipped all 264, and the
school's own front stood dark while its dormers and the boarding house glowed.
No geometry check could see it: the parts were all present, in the right place,
the right size, and correctly framed. They were simply the wrong material.

Three questions, per window:

  A. is it LIT -- is the pane itself neon, or is there a neon leaf inside it?
  B. is it FRAMED -- a window is an opening with dressed stone round it. A bare
     slab set in a wall with no surround, jamb, mullion, sill or hood is a
     painted rectangle.
  C. is the glass BURIED -- set so deep in its own wall that nothing can see it.

    python3 tools/render_map.py .
    python3 tools/window_check.py
"""
import json, math, os, sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

# What counts as a window pane.
# NOT "Pane": it is a substring of "Panel", and the map is full of ceiling
# panels, planter panels and office panels that are not windows.
GLAZING = ("Window", "Lancet", "Glazing", "Casement", "Oculus")
# ... and what does not. Every one of these is glass, and none of them is a
# window: a glowing drinks cabinet is not the effect we are after, and a
# trophy case lit from inside is lit by its own fittings.
NOT_GLAZING = (
    "Vending", "Cooler", "Jug", "Bottle", "Canopy", "Car", "Bus", "Display",
    "Case", "Cabinet", "Screen", "Monitor", "Tank", "Aquarium", "Clock",
    "Trophy", "Shelter", "Kiosk", "Booth",
    "Door", "Hatch", "Mirror", "Picture", "Frame", "Lamp", "Lantern", "Bulb",
    # the dressing round an opening is named for the opening; it is not glass
    "Surround", "Mullion", "Transom", "Sill", "Jamb", "Hood", "Muntin",
    "Box", "Ledge", "Head", "Reveal", "Bar", "Sash",
    # a leaf is the lit surface PUT INSIDE a pane by litWindows. It is the
    # answer to rule A, not another thing to ask it of.
    "Leaf", "Panel",
)
# The dressing a real opening carries. Two of these near a pane is a framed
# window; none is a rectangle painted on a wall.
DRESSING = ("Surround", "Mullion", "Transom", "Sill", "Jamb", "Hood", "Muntin",
            "Frame", "Reveal", "Head", "Arch", "Keystone", "Bar", "Sash",
            "Lintel", "Cill", "Apron")
# Structure a pane can be buried in.
WALLS = ("Wall", "Brick", "Facade", "Stone", "Partition", "Gable", "Tower",
         "Shell", "Block", "Range", "Plinth")

# A pane smaller than this is a fanlight or a bit of detail, not an elevation
# window, and holding it to the rule would report every porthole in the map.
MIN_FACE = 3.0        # square studs of glazed face
DRESS_NEAR = 7.0      # how far dressing may stand from the pane it dresses
BURIED = 0.90         # of the pane's volume inside one wall part


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(q[i] - half[i], q[i] + half[i]) for i in range(3)]


def overlap_volume(a, b):
    v = 1.0
    for i in range(3):
        lo, hi = max(a[i][0], b[i][0]), min(a[i][1], b[i][1])
        if hi <= lo:
            return 0.0
        v *= hi - lo
    return v


def glazed_face(p):
    """The area of the pane you can actually see: its two largest dimensions."""
    s = sorted(p["s"])
    return s[1] * s[2]


def is_pane(p):
    n = p["n"]
    if any(w in n for w in NOT_GLAZING):
        return False
    if any(w in n for w in GLAZING):
        return True
    # a part actually named Glass, which is how most of the drawn buildings
    # name theirs
    return "Glass" in n


def main():
    parts = json.load(open(DUMP))
    panes = [p for p in parts if is_pane(p) and glazed_face(p) >= MIN_FACE]
    if not panes:
        print("FAIL - no windows found at all; the name list is wrong")
        return 1

    # index everything else by cell so the near-tests are not quadratic
    CELL = 16.0
    grid = defaultdict(list)
    for p in parts:
        b = aabb(p)
        for cx in range(int(b[0][0] // CELL), int(b[0][1] // CELL) + 1):
            for cz in range(int(b[2][0] // CELL), int(b[2][1] // CELL) + 1):
                grid[(cx, cz)].append(p)

    def near(p, pad):
        b = aabb(p)
        seen, out = set(), []
        for cx in range(int((b[0][0] - pad) // CELL), int((b[0][1] + pad) // CELL) + 1):
            for cz in range(int((b[2][0] - pad) // CELL), int((b[2][1] + pad) // CELL) + 1):
                for q in grid.get((cx, cz), ()):
                    if id(q) not in seen:
                        seen.add(id(q))
                        out.append(q)
        return out

    dark, bare, buried = Counter(), Counter(), Counter()
    for pane in panes:
        pb = aabb(pane)
        pvol = max(1e-6, (pb[0][1] - pb[0][0]) * (pb[1][1] - pb[1][0]) * (pb[2][1] - pb[2][0]))
        neighbours = near(pane, DRESS_NEAR)

        # ---- A. lit ----
        lit = pane["m"] == "Neon" or float(pane.get("lit") or 0) > 0
        if not lit:
            for q in neighbours:
                if q is pane:
                    continue
                if q["m"] != "Neon" and float(q.get("lit") or 0) <= 0:
                    continue
                # a leaf INSIDE the pane, not a lamp standing near the wall
                if overlap_volume(pb, aabb(q)) > 0.0:
                    lit = True
                    break
        if not lit:
            dark[pane["n"]] += 1

        # ---- B. framed ----
        centre = pane["p"]
        face = glazed_face(pane)
        dress, framed_by_one = 0, False
        for q in neighbours:
            if q is pane or not any(w in q["n"] for w in DRESSING):
                continue
            d = math.dist(centre, q["p"])
            if d <= DRESS_NEAR:
                dress += 1
                if glazed_face(q) > face:
                    framed_by_one = True
        # Two bars, OR one surround bigger than the opening it dresses. A
        # tower lancet is a single ashlar surround nine by twelve round a pane
        # six by nine and a half -- a properly dressed opening, and holding it
        # to "two or more parts" would report all fifty-six of them.
        if dress < 2 and not framed_by_one:
            bare[pane["n"]] += 1

        # ---- C. buried ----
        # Not "mostly inside a wall" -- a window is SUPPOSED to be set into
        # its wall, and the Academy's panes are 2.4 deep in a 2.2 brick band,
        # which is 92% contained and perfectly visible. Buried means the wall
        # closes over it on every axis: no face of the glass reaches daylight.
        for q in neighbours:
            if q is pane or not any(w in q["n"] for w in WALLS):
                continue
            wb = aabb(q)
            if all(wb[i][0] <= pb[i][0] + 0.02 and wb[i][1] >= pb[i][1] - 0.02
                   for i in range(3)):
                buried[pane["n"]] += 1
                break

    # A school where every window without exception is burning reads as a
    # render rather than as a building people live in, so the builders leave
    # about one in nine dark on purpose. A QUARTER dark is not that -- it is an
    # elevation nobody lit.
    DARK_SHARE = 0.25
    notes = []
    if dark and sum(dark.values()) <= DARK_SHARE * len(panes):
        worst = ", ".join(f"{n} x {k}" for k, n in dark.most_common(3))
        notes.append(f"  {sum(dark.values()):4d} dark    on purpose, {sum(dark.values()) / len(panes):.0%} of the map ({worst})")
        dark = Counter()

    lines = []
    for label, counter, why in (
        ("dark", dark, "carry no lit leaf; at night they are holes in the elevation"),
        ("bare", bare, "have no surround, jamb, mullion or sill: a rectangle painted on a wall"),
        ("buried", buried, "sit inside their own wall, where nothing can see them"),
    ):
        if not counter:
            continue
        worst = ", ".join(f"{n} x {k}" for k, n in counter.most_common(4))
        lines.append(f"  {sum(counter.values()):4d} {label:7} {why}\n           {worst}")

    print(f"{len(panes)} windows measured")
    for note in notes:
        print(note)
    for line in lines:
        print(line)
    if lines:
        print("FAIL - the night look is only as good as the darkest elevation")
        return 1
    print("PASS - every window is lit, framed and visible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
