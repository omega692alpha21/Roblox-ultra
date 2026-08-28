#!/usr/bin/env python3
"""Hold the built school to tools/school_plan.py.

Every other check in this repo asks whether the map WORKS -- is there floor,
can you reach it, does anything clip. None of them ask whether it is the
building it is supposed to be. That is how the school ended up with a
volleyball court in a light well, a glasshouse in a quadrangle, a bank of
lockers in front of the principal's door and two signs pointing at each
other's rooms: every one of those passed every check, because none of them
is broken. They are just wrong.

    python3 tools/render_map.py . tools
    python3 tools/plan_check.py
"""
import json, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import school_plan as plan

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")
PROPS = os.path.join(os.path.dirname(DUMP) or ".", "_map_props.json")
REPO = sys.argv[2] if len(sys.argv) > 2 else "."


def aabb(part):
    r, s, p = part["r"], part["s"], part["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(p[i] - half[i], p[i] + half[i]) for i in range(3)]


def main():
    parts = json.load(open(DUMP))
    boxes = {id(p): aabb(p) for p in parts}
    bad = []

    # ---- 1. the rooms may not overlap each other -------------------------
    for i, (an, ar, al, ak) in enumerate(plan.ROOMS):
        for bn, br, bl, bk in plan.ROOMS[i + 1:]:
            if al != bl:
                continue
            if (ar[0] < br[2] and br[0] < ar[2] and ar[1] < br[3] and br[1] < ar[3]):
                bad.append(("plan", f"{an} and {bn} overlap on storey {al}"))

    # ---- 2. nothing outdoor-only may stand under a roof ------------------
    roof = [boxes[id(p)] for p in parts
            if p["n"].startswith("RoofSlab") or p["n"].startswith("UpperFloor")]

    def roofed(x, z):
        return any(b[0][0] <= x <= b[0][1] and b[2][0] <= z <= b[2][1] for b in roof)

    for p in parts:
        if p["p"][1] > plan.ROOF_Y:
            continue
        if any(k in p["n"] for k in plan.OUTDOOR_ONLY) and roofed(p["p"][0], p["p"][2]):
            where = plan.room_at(p["p"][0], p["p"][2])
            bad.append(("indoors", f"{p['n']} at {[round(v) for v in p['p']]} is under a roof"
                                   f" ({where[0] if where else 'no room'})"))

    # ---- 3. corridors keep their middle lane clear -----------------------
    for name, rect, level, kind in plan.ROOMS:
        if kind != "corridor":
            continue
        y = plan.GROUND_Y if level == 0 else plan.UPPER_Y
        cz = (rect[1] + rect[3]) / 2
        for p in parts:
            if not p.get("cc"):
                continue
            b = boxes[id(p)]
            if b[1][1] < y + 1.0 or b[1][0] > y + 7.0:
                continue      # not at body height on this storey
            # inside the corridor's RUN, not at either end of it: the block's
            # own outer facade sits across the last few studs of the hall and
            # is the corridor's end wall, not an obstruction in it
            if b[0][1] < rect[0] + 6 or b[0][0] > rect[2] - 6:
                continue
            # the part's CENTRE, not its extents: a wall that runs along the
            # corridor's edge has a bounding box reaching into it, and the
            # question is what is STANDING in the lane, not what leans over it
            if abs(p["p"][2] - cz) < plan.CORRIDOR_CLEAR_HALF:
                bad.append(("corridor", f"{p['n']} at {[round(v) for v in p['p']]} stands in "
                                        f"{name}'s middle lane"))

    # ---- 4. door signs must name the room behind them --------------------
    signs = {}
    text = open(os.path.join(REPO, "src/ServerScriptService/Services/MapService.luau")).read()
    block = text[text.index("local DOOR_SIGNS"):]
    block = block[:block.index("\n}")]
    import re
    for m in re.finditer(r'label = "([^"]+)".*?Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\), face = (-?1)', block):
        signs[m.group(1)] = (float(m.group(2)), float(m.group(4)), int(m.group(5)))
    ALIAS = {
        "ROOM 101 · MATHS": "Room 101", "MUSIC ROOM": "Music room", "GYM": "Gym",
        "CAFETERIA": "Cafeteria", "OFFICE · THE STORE": "Principal's office",
        "TROPHY HALL": "Trophy hall", "DETENTION": "Detention",
        "GREENHOUSE": "West quad", "EAST LAB": "East quad",
    }
    for label, (x, z, face) in signs.items():
        # the room is on the far side of the wall the sign hangs on
        inside = plan.room_at(x, z - face * plan.DOOR_SIGN_DEPTH)
        want = ALIAS.get(label)
        if want is None:
            continue
        if inside is None or inside[0] != want:
            bad.append(("sign", f'"{label}" at ({x:.0f},{z:.0f}) hangs on '
                                f'{inside[0] if inside else "nothing"}, not {want}'))

    # ---- 5. doorways stay clear, of parts AND of props -------------------
    prop_sizes = {}
    sizes_path = os.path.join(REPO, "src/ReplicatedStorage/Config/PropSizes.luau")
    if os.path.exists(sizes_path):
        for m in re.finditer(r"(\w+) = Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)",
                             open(sizes_path).read()):
            prop_sizes[m.group(1)] = [float(m.group(i)) for i in (2, 3, 4)]
    occupants = [(p["n"], p["p"], boxes[id(p)]) for p in parts if p.get("cc")]
    if os.path.exists(PROPS):
        for row in json.load(open(PROPS)):
            size = prop_sizes.get(row["k"])
            if not size:
                continue
            sc = row.get("sc") or 1.0
            s = [v * sc for v in size]
            up = [row["r"][1], row["r"][4], row["r"][7]]
            edge = s[1] / 2 * (-1.0 if row.get("hang") else 1.0)
            c = [row["p"][i] + up[i] * edge for i in range(3)]
            occupants.append(("prop " + row["k"], c,
                              [(c[i] - s[i] / 2, c[i] + s[i] / 2) for i in range(3)]))
    for name, x, y, z, w, h, d in plan.DOORWAYS:
        lane = [(x - w / 2, x + w / 2), (y - h / 2, y + h / 2), (z - d / 2, z + d / 2)]
        for n, p, b in occupants:
            if "Floor" in n or any(k in n for k in ("Stripe", "Band", "Carpet", "Rug",
                                                     "Trim", "Sill", "Panel", "Window",
                                                     "Post", "Jamb", "Lintel", "Sign")):
                continue     # the door frame is not a blocked door
            if all(b[i][0] < lane[i][1] and lane[i][0] < b[i][1] for i in range(3)):
                bad.append(("doorway", f"{n} at {[round(v) for v in p]} blocks the {name}"))

    groups = {}
    for kind, message in bad:
        groups.setdefault(kind, []).append(message)
    for kind in ("plan", "indoors", "sign", "corridor", "doorway"):
        rows = groups.get(kind, [])
        if not rows:
            continue
        print(f"  {kind.upper()} ({len(rows)})")
        seen = set()
        for message in rows:
            key = message.split(" at ")[0]
            if key in seen and len(seen) > 6:
                continue
            seen.add(key)
            print(f"      {message}")
    print(f"{'FAIL' if bad else 'PASS'} - the school matches its plan "
          f"({len(plan.ROOMS)} rooms, {len(plan.DOORWAYS)} doorways, {len(bad)} departures)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
