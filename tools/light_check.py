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


def main():
    parts = json.load(open(DUMP))
    lights = [
        (p["p"], float(p.get("lit") or 0))
        for p in parts
        if float(p.get("lit") or 0) > 0
    ]
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

    bad = []
    for name, cx, cz, hx, hz, y in ROOMS:
        samples = dark = 0
        for i in range(int(hx * 2 / STEP) + 1):
            for j in range(int(hz * 2 / STEP) + 1):
                x = cx - hx + i * STEP
                z = cz - hz + j * STEP
                if not roofed(x, z, y):
                    continue  # open to the sky; the sun does this one
                samples += 1
                # a light reaches a spot if the spot is inside its range
                if not any(
                    (px - x) ** 2 + (py - y) ** 2 + (pz - z) ** 2 < rng * rng
                    for (px, py, pz), rng in lights
                ):
                    dark += 1
        if samples == 0:
            continue
        share = dark / samples
        if share > 0.5:
            bad.append((name, share, samples))

    for name, share, samples in bad:
        print(f"  {name:22s} {share * 100:3.0f}% of its floor is out of reach of any light "
              f"({samples} samples)")
    print(f"{'FAIL' if bad else 'PASS'} - {len(ROOMS)} rooms, "
          + (f"{len(bad)} in the dark" if bad else "every one lit"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
