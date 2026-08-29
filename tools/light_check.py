#!/usr/bin/env python3
"""Find rooms that are caves.

The map runs Future lighting, which means an interior gets no light at all
except from its own fixtures and whatever comes through a window. A room with
a roof over it and nothing emitting inside it renders black -- and none of the
geometry checks can see that, because a black room is a perfectly valid room.

This samples the floor of every named interior, asks whether any light source
is close enough to reach it, and reports the ones in the dark.

    python3 tools/light_check.py
"""
import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = os.path.join(HERE, "_map_export.json")

# Rooms that are meant to be lit, as (name, x, z, half-width, half-depth, y).
ROOMS = [
    ("main hallway", 0, 65, 210, 14, 1),
    ("lobby", 0, 100, 28, 20, 1),
    ("atrium", 0, 22, 28, 24, 1),
    ("upper corridor", 0, 65, 210, 14, 17),
    ("assembly hall", 0, -100, 46, 28, 1),
    ("gymnasium", 425, 437, 82, 22, 1),
    ("library", -320, -300, 44, 32, 1),
    ("cafeteria", 372, -300, 36, 18, 1),
    ("principal office", -204, 35, 18, 26, 1),
    ("detention", -438, -14, 34, 16, 1),
    ("trophy room", 204, -29, 18, 26, 1),
    ("room 101", -74, -95, 12, 26, 1),
    ("music room", 74, -95, 12, 26, 1),
    ("east lab", 116, -28, 16, 15, 1),
    ("greenhouse", -116, -28, 16, 15, 1),
    # The boarding house, room by room off CampusPlan's grid. What used to be
    # here was ("west dorm", -176, -212) and ("east dorm", 176, -212) -- the
    # two blocks the drawing replaced with one range -- so the check was
    # sampling open grass on the Dorm Court's flanks and the range itself, the
    # building every boarder sleeps in, was never looked at.
    ("dorm common room", 0, -344, 26, 15, 1),
    ("dorm 1", -114, -344, 24, 15, 1),
    ("dorm 4", 114, -344, 24, 15, 1),
    ("dorm corridor", 0, -310, 130, 12, 1),
    ("dorm lobby", 0, -276, 26, 15, 1),
    ("warden's flat", -114, -276, 24, 15, 1),
    ("laundry", 114, -276, 24, 15, 1),
    ("dorm study", 0, -344, 26, 15, 16),
    ("upper landing", 0, -276, 26, 15, 16),
    ("rooftop block", 210, 400, 48, 48, 1),
    ("staff common room", -300, -170, 38, 28, 4),
    ("staff studies", -300, -170, 38, 28, 20),
    ("headmaster office", -300, -170, 38, 28, 36),
    ("headmaster turret", -249, -186, 8, 8, 20),
    ("library passage", -393, -290, 26, 5, 1),
]

STEP = 8.0
# Below this the floor is not lit. Same figure and same falloff as
# nightlight_check, so indoors and outdoors are held to one standard.
DARK = 0.045
SHARE = 0.5
HOLE = 700.0        # square studs of contiguous dark floor


def plan_rooms():
    """Every room the drawing knows about.

    The list above is thirty rooms typed out by hand. CampusPlan draws far
    more than thirty -- the Academy alone has fifty-odd cells over three
    storeys -- and every one not on the list went unchecked. That is why the
    Academy's corridors, its labs and the headmaster's own office could sit at
    a hundred per cent dark with this check reporting every room lit.
    """
    path = os.path.join(HERE, "_campus_plan.json")
    if not os.path.exists(path):
        return []
    plan = json.load(open(path))
    out = []
    for b in plan.get("buildings", ()):
        for st in b.get("storeys", ()):
            for c in st.get("cells", ()):
                x0, z0, x1, z1 = c["rect"]
                out.append((f"{b['name']}/{c['name']} L{st['index']}",
                            (x0 + x1) / 2, (z0 + z1) / 2,
                            (x1 - x0) / 2, (z1 - z0) / 2, st["y"] + 1.0))
    return out


def main():
    parts = json.load(open(DUMP))
    # Real PointLights with their range AND brightness, not a list of points
    # each of which "covers" a sphere of its range. A range-34 fitting does not
    # light the floor thirty studs away; it puts about six thousandths on it.
    lights = []
    for p in parts:
        for lamp in p.get("lamps") or ():
            lights.append((p["p"][0], p["p"][1], p["p"][2], float(lamp[0]), float(lamp[1])))
    print(f"{len(lights)} light sources in the map")

    # Roofs, so an open courtyard is not reported as a dark room: daylight is
    # a light source and the sky is not in the part dump.
    roofs = []
    for p in parts:
        if not p.get("cc"):
            continue
        r, sz, pos = p["r"], p["s"], p["p"]
        half = [
            0.5 * sum(abs(r[row * 3 + col]) * sz[col] for col in range(3))
            for row in range(3)
        ]
        if half[0] * half[2] < 30:
            continue  # too small to be a ceiling
        roofs.append((pos[0] - half[0], pos[0] + half[0],
                      pos[2] - half[2], pos[2] + half[2],
                      pos[1] - half[1]))

    def roofed(x, z, y):
        return any(
            x0 <= x <= x1 and z0 <= z <= z1 and y + 3 < base < y + 46
            for x0, x1, z0, z1, base in roofs
        )

    def landing(x, y, z):
        total = 0.0
        for lx, ly, lz, rng, bright in lights:
            dx, dy, dz = lx - x, ly - y, lz - z
            d2 = dx * dx + dy * dy + dz * dz
            if d2 >= rng * rng or dy <= 0:
                continue
            d = math.sqrt(d2) or 1e-6
            fall = 1.0 - d / rng
            total += bright * (dy / d) * fall * fall
        return total

    rooms = ROOMS + plan_rooms()
    bad, dark_cells = [], set()
    for name, cx, cz, hx, hz, y in rooms:
        samples = dark = 0
        for i in range(int(hx * 2 / STEP) + 1):
            for j in range(int(hz * 2 / STEP) + 1):
                x = cx - hx + i * STEP
                z = cz - hz + j * STEP
                if not roofed(x, z, y):
                    continue  # open to the sky; the sun does this one
                samples += 1
                if landing(x, y, z) < DARK:
                    dark += 1
                    dark_cells.add((int(x // STEP), int(z // STEP), round(y)))
        if samples == 0:
            continue
        share = dark / samples
        if share > SHARE:
            bad.append((name, share, samples))

    holes, seen = [], set()
    for c in dark_cells:
        if c in seen:
            continue
        stack, grp = [c], [c]
        seen.add(c)
        while stack:
            cx_, cz_, cy = stack.pop()
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = (cx_ + d[0], cz_ + d[1], cy)
                if nb in dark_cells and nb not in seen:
                    seen.add(nb)
                    stack.append(nb)
                    grp.append(nb)
        if len(grp) * STEP * STEP >= HOLE:
            holes.append((len(grp) * STEP * STEP,
                          round(sum(g[0] for g in grp) / len(grp) * STEP),
                          round(sum(g[1] for g in grp) / len(grp) * STEP),
                          grp[0][2]))

    bad.sort(key=lambda r: -r[1])
    for name, share, samples in bad[:16]:
        print(f"  {name:34s} {share * 100:3.0f}% of its floor is unlit ({samples} samples)")
    holes.sort(reverse=True)
    for area, hx_, hz_, hy in holes[:8]:
        print(f"  {area:6.0f} sq studs of unbroken dark at ({hx_}, {hy}, {hz_})")
    print(f"{'FAIL' if (bad or holes) else 'PASS'} - {len(rooms)} rooms, "
          + (f"{len(bad)} in the dark, {len(holes)} dark holes"
             if (bad or holes) else "every one lit"))
    return 1 if (bad or holes) else 0


if __name__ == "__main__":
    sys.exit(main())
