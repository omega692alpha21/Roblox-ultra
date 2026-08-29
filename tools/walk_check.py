#!/usr/bin/env python3
"""Can you get anywhere on this campus without crossing grass?

reach_check asks whether every room can be reached from the front doors. It
walks anywhere a character can stand, which includes a thousand studs of lawn,
so it has always passed on a campus whose walks were confetti.

The reference site plan is a walk NETWORK first and a set of buildings second.
Ours was 7,956 paved cells in seventy-eight disconnected pieces: two of them
were the campus -- 72,240 square studs north of the Academy and 24,368 south
of it, touching nowhere -- and the rest were islands. The gymnasium's apron.
The rooftop block's apron. The cafeteria's own doorstep, at 320 square studs.
The dorms' south door at 368. A player leaving any of those doors was on grass.

This floods the walkable paving four studs to a cell and asks what share of it
is one connected network, and whether every building's door is on it. Sports
surfaces and interior floors are not walks and are not counted.

    python3 tools/render_map.py .
    python3 tools/walk_check.py
"""
import json, os, sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

WALK = ("Path", "Walk", "Paving", "Apron", "Terrace", "Drive", "Plaza", "Road",
        "Step", "Landing", "Forecourt")
# A pitch, a track and a sports hall floor are surfaces, not walks; and the
# dressing that edges a walk is not the walk.
# NOT "Court": the Great Court's own paving is CourtPaving, its walks are
# CourtPath and CourtRondel and DormCourtWalk, and excluding the word severed
# the middle of the campus from itself -- the check then reported the network
# as 4,320 square studs and eight doors stranded, which was the check's fault
# and not the map's. The sports surfaces (BasketballCourt, CourtDeck, the
# track) match nothing in WALK, so they need no exclusion at all.
NOT = ("Kerb", "Joint", "Line", "Marking", "Lawn", "Wall", "Roof", "Ceiling",
       "Hedge", "Bed", "Net", "Post", "Basin", "Water", "Bowl", "Jet", "Rail",
       "Key")

G = 4.0
SHARE = 0.90        # of walk area that must be in ONE network
# Every outside door on the campus, and the ground each one lands on.
DOORS = [
    ("the Academy's north doors", 0, 130),
    ("the Academy's south doors", 0, -130),
    ("the main gate", 0, 500),
    ("the Student Dorms, court side", 0, -248),
    ("the Student Dorms, back", 0, -378),
    ("the Library", -320, -251),
    ("the Cafeteria", 316, -248),
    ("the Detention Hall", -312, 20),
    ("the Gymnasium", 326, 396),
    ("the boiler house", 268, 400),
    ("the staff lodge", -256, -170),
]
NEAR = 5            # cells


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(q[i] - half[i], q[i] + half[i]) for i in range(3)]


def main():
    parts = json.load(open(DUMP))
    cells = set()
    for p in parts:
        n = p["n"]
        if any(w in n for w in NOT) or not any(w in n for w in WALK):
            continue
        b = aabb(p)
        if b[1][1] > 4.5 or b[1][1] < -1.0:
            continue
        for gx in range(int(b[0][0] // G), int(b[0][1] // G) + 1):
            for gz in range(int(b[2][0] // G), int(b[2][1] // G) + 1):
                cells.add((gx, gz))
    if not cells:
        print("FAIL - no walks found at all; the name list is wrong")
        return 1

    seen, comps = set(), []
    for c in cells:
        if c in seen:
            continue
        q, grp = deque([c]), [c]
        seen.add(c)
        while q:
            cx, cz = q.popleft()
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = (cx + d[0], cz + d[1])
                if nb in cells and nb not in seen:
                    seen.add(nb)
                    q.append(nb)
                    grp.append(nb)
        comps.append(grp)
    comps.sort(key=len, reverse=True)
    main_net = set(comps[0])
    share = len(main_net) / len(cells)

    stranded = []
    for name, dx, dz in DOORS:
        gx, gz = int(dx // G), int(dz // G)
        if not any((gx + ox, gz + oz) in main_net
                   for ox in range(-NEAR, NEAR + 1)
                   for oz in range(-NEAR, NEAR + 1)):
            stranded.append(name)

    print(f"{round(len(cells) * G * G)} sq studs of walk in {len(comps)} pieces; "
          f"the network is {share:.0%} of it")
    if share < SHARE or stranded:
        for g in comps[1:9]:
            xs = [c[0] * G for c in g]
            zs = [c[1] * G for c in g]
            print(f"  stranded {len(g) * G * G:7.0f} sq studs  "
                  f"x {min(xs):.0f}..{max(xs):.0f}  z {min(zs):.0f}..{max(zs):.0f}")
        for name in stranded:
            print(f"  no walk reaches {name}")
        print(f"FAIL - the campus is not one walk network "
              f"({len(stranded)} doors stranded)")
        return 1
    print("PASS - one walk network, and every door is on it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
