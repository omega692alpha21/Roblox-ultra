#!/usr/bin/env python3
"""Find writing that nobody can read.

A sign is a face with words on it, and the two ways to get one wrong are to
put the words on the side pressed against a wall, and to put them on a side
nothing can stand in front of. Neither breaks anything: the sign exists, it is
lit, it is reachable, every other check in this repo passes -- and the school's
own founder's plaque faced into nine studs of marble for the whole life of the
project, so everyone walking up from the school saw a blank sheet of bronze.

For each face carrying a SurfaceGui, this steps a stud and a half out along
that face's outward normal and asks two questions: is that point inside
something solid, and is there anywhere near it a player could stand.

    python3 tools/render_map.py . tools
    python3 tools/sign_check.py
"""
import json, math, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

CELL = 16.0
STAND_OFF = 1.6       # how far in front of the face to test
# Roblox's NormalId, as the part's own local axis and sign
FACES = {
    "Front": (2, -1), "Back": (2, 1),
    "Right": (0, 1), "Left": (0, -1),
    "Top": (1, 1), "Bottom": (1, -1),
}


def aabb(part):
    r, s, p = part["r"], part["s"], part["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(p[i] - half[i], p[i] + half[i]) for i in range(3)]


def local(part, point):
    r = part["r"]
    d = [point[i] - part["p"][i] for i in range(3)]
    return [sum(r[row * 3 + col] * d[row] for row in range(3)) for col in range(3)]


def inside(part, point, pad=0.0):
    q = local(part, point)
    s = part["s"]
    return all(abs(q[i]) <= s[i] / 2 + pad for i in range(3))


def main():
    parts = json.load(open(DUMP))
    solids = [p for p in parts if p.get("cc")]
    index = defaultdict(list)
    for p in solids:
        b = aabb(p)
        for cx in range(int(b[0][0] // CELL), int(b[0][1] // CELL) + 1):
            for cz in range(int(b[2][0] // CELL), int(b[2][1] // CELL) + 1):
                index[(cx, cz)].append(p)

    # A sign is only unreadable when EVERY face carrying words reads into
    # something. Most of these boards are written on both sides on purpose --
    # a room sign facing the corridor and the room -- and reporting the one
    # that faces the wall behind it is noise.
    bad, checked = [], 0
    for part in parts:
        faces = part.get("gui") or ()
        blocked_faces = []
        for name in faces:
            axis, sign = FACES.get(name, (2, -1))
            checked += 1
            r = part["r"]
            # the face's outward normal in world space is that local axis's
            # column of the rotation, times the sign
            normal = [r[0 * 3 + axis] * sign, r[1 * 3 + axis] * sign, r[2 * 3 + axis] * sign]
            reach = part["s"][axis] / 2 + STAND_OFF
            probe = [part["p"][i] + normal[i] * reach for i in range(3)]
            blocker = None
            for other in index.get((int(probe[0] // CELL), int(probe[2] // CELL)), ()):
                if other is part:
                    continue
                if inside(other, probe, pad=-0.05):
                    blocker = other["n"]
                    break
            if blocker:
                blocked_faces.append((name, blocker))
        if faces and len(blocked_faces) == len(faces):
            bad.append((part["n"], "/".join(f for f, _ in blocked_faces),
                        [round(v) for v in part["p"]], blocked_faces[0][1]))

    for name, face, at, blocker in bad[:20]:
        print(f"      {name:24s} {face:6s} at {at} reads into {blocker}")
    print(f"{'FAIL' if bad else 'PASS'} - {checked} sign faces, {len(bad)} facing into something")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
