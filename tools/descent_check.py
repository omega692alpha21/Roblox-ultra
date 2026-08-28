#!/usr/bin/env python3
"""Walk from the bottom of each spiral to the middle of the pyramid.

The estate under the school is built by SanctumMap and the way down to it is
built by MapService, and until now no check has ever seen both at once.
world_audit walks the shafts and the spirals against the school's dump and
stops at the bottom tread. sanctum_check floods the estate against the
sanctum's dump and starts at the boulevard's far end -- the point the
HEADMASTER's tunnel arrives at, which is not where either spiral puts you.
So the one place a player is actually delivered, and the forty studs between
that place and the pyramid's door, were checked by nothing.

This merges the two dumps into one grid and floods from each spiral's bottom
tread, which is the coordinate the game genuinely leaves you standing on.

    python3 tools/sanctum_export.py && python3 tools/render_map.py . tools
    python3 tools/descent_check.py
"""
import json, math, os, sys
from collections import deque

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CELL = 1.0
BODY_LOW, BODY_HIGH = 0.6, 5.0
STEP_UP, STEP_DOWN = 3.0, 3.0
STEP = 2.2
FLOOR_Y = -119.5

# Where each spiral leaves you: centre, radius and the angle of its LAST tread.
# Same numbers MapService builds them from, so a spiral that moves and takes
# its landing with it is caught here rather than in a screenshot.
# (name, centre x, centre z, radius, angle of the FIRST tread, top y). The
# helix turns as it drops, so the last tread is not at the first tread's
# bearing -- assuming it was put the landing a quarter of the way round the
# shaft from where the stair actually ends.
SPIRAL_RISE = 1.4
SPIRAL_PER_TURN = 24
DESCENTS = [
    ("library spiral", -100.0, -222.0, 6.5, 0.0, -1.4),
    ("headmaster spiral", -249.0, -186.0, 7.0, math.pi, 33.6),
]


def last_tread(cx, cz, radius, facing, top):
    steps = max(4, int((top - FLOOR_Y) / SPIRAL_RISE))
    angle = facing + steps * (math.pi * 2 / SPIRAL_PER_TURN)
    return cx + math.cos(angle) * radius, cz + math.sin(angle) * radius

# What being "in the pyramid" means, as POINTS rather than as parts. The grand
# floor is ninety-five studs across: touching one cell of its outermost edge is
# not standing in the hall, and a check that accepts that would pass on a
# pyramid you can only see the doorstep of.
MUST_REACH = [
    ("the atrium", (-63.9, -232.0)),
    ("the grand hall", (0.0, -232.0)),
    ("the boulevard", (-123.0, -232.0)),
]


def aabb(part):
    r, s, p = part["r"], part["s"], part["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(p[i] - half[i], p[i] + half[i]) for i in range(3)]


def footprint(part, box, x_lo, z_lo, nx, nz, span):
    """The cells a part actually stands on, as a boolean mask over its own box.

    The headmaster's tunnel runs on a diagonal, and its side walls are two
    studs thick and ninety long. Their BOUNDING boxes are forty-odd studs wide
    -- wide enough to swallow the corridor they are the sides of -- so a
    box-only test reads the whole tunnel as solid rock and the estate as
    sealed. Yawed parts get tested against their own footprint instead; only
    something tipped on its end still uses the box, because there the local
    half-sizes say nothing useful.
    """
    x0, x1 = span(box[0][0], box[0][1], x_lo, nx)
    z0, z1 = span(box[2][0], box[2][1], z_lo, nz)
    if x1 <= x0 or z1 <= z0:
        return None
    r = part["r"]
    yawed = abs(r[1]) < 1e-6 and abs(r[4] - 1.0) < 1e-6 and abs(r[7]) < 1e-6
    if not yawed:
        return x0, x1, z0, z1, None
    px, _, pz = part["p"]
    sx, _, sz = part["s"]
    gx = (np.arange(x0, x1, dtype=np.float32) * CELL + x_lo + CELL / 2) - px
    gz = (np.arange(z0, z1, dtype=np.float32) * CELL + z_lo + CELL / 2) - pz
    dx = gx[:, None]
    dz = gz[None, :]
    # the point in the part's own frame: R is row-major, so going the other way
    # is R-transpose, which is the COLUMN dotted with the delta
    lx = r[0] * dx + r[6] * dz
    lz = r[2] * dx + r[8] * dz
    mask = (np.abs(lx) <= sx / 2 + 1e-3) & (np.abs(lz) <= sz / 2 + 1e-3)
    if not mask.any():
        return None
    return x0, x1, z0, z1, mask


def main():
    parts = []
    for name in ("_map_export.json", "_sanctum_export.json"):
        path = os.path.join(HERE, name)
        if not os.path.exists(path):
            print(f"missing {name} -- run render_map.py and sanctum_export.py first")
            return 1
        for part in json.load(open(path)):
            part["src"] = name
            parts.append(part)

    # Only the storey the boulevard is on. The chambers stack above it and are
    # reached by pads, which sanctum_check already proves; what is in question
    # here is whether you can WALK from the stair to the door.
    solids = [
        p for p in parts
        if p.get("cc") and aabb(p)[1][1] > FLOOR_Y - 6 and aabb(p)[1][0] < FLOOR_Y + 22
    ]
    boxes = [aabb(p) for p in solids]
    if not boxes:
        print("nothing solid at the estate's floor level")
        return 1

    x_lo = min(b[0][0] for b in boxes) - 8
    z_lo = min(b[2][0] for b in boxes) - 8
    nx = int((max(b[0][1] for b in boxes) + 8 - x_lo) / CELL) + 1
    nz = int((max(b[2][1] for b in boxes) + 8 - z_lo) / CELL) + 1

    def span(lo, hi, origin, limit):
        first = int(math.ceil((lo - origin - CELL / 2) / CELL))
        last = int(math.floor((hi - origin - CELL / 2) / CELL)) + 1
        return max(first, 0), min(last, limit)

    floor = np.full((nx, nz), -1e9, dtype=np.float32)
    ranges = []
    for part, box in zip(solids, boxes):
        cells = footprint(part, box, x_lo, z_lo, nx, nz, span)
        if cells is None:
            continue
        x0, x1, z0, z1, mask = cells
        ranges.append((x0, x1, z0, z1, mask, box[1][0], box[1][1]))
        if FLOOR_Y - STEP_DOWN <= box[1][1] <= FLOOR_Y + STEP_UP:
            patch = floor[x0:x1, z0:z1]
            if mask is None:
                np.maximum(patch, box[1][1], out=patch)
            else:
                np.maximum(patch, np.where(mask, box[1][1], -1e9), out=patch)
    blocked = np.zeros((nx, nz), dtype=bool)
    for x0, x1, z0, z1, mask, bottom, top in ranges:
        patch = floor[x0:x1, z0:z1]
        hit = (bottom < patch + BODY_HIGH) & (top > patch + BODY_LOW)
        if mask is not None:
            hit &= mask
        blocked[x0:x1, z0:z1] |= hit
    walkable = (floor > -1e8) & ~blocked

    # what each cell belongs to, so a failure can name the wall it stopped at
    owner = np.empty((nx, nz), dtype=object)
    for part, box in zip(solids, boxes):
        cells = footprint(part, box, x_lo, z_lo, nx, nz, span)
        if cells is None or box[1][1] < FLOOR_Y - 2:
            continue
        x0, x1, z0, z1, mask = cells
        patch = owner[x0:x1, z0:z1]
        if mask is None:
            patch[:] = part["n"]
        else:
            patch[mask] = part["n"]

    bad = []
    for name, cx, cz, radius, facing, top in DESCENTS:
        seen = np.zeros((nx, nz), dtype=bool)
        queue = deque()
        foot = last_tread(cx, cz, radius, facing, top)
        fx, fz = int((foot[0] - x_lo) / CELL), int((foot[1] - z_lo) / CELL)
        started = 0
        for dx in range(-7, 8):
            for dz in range(-7, 8):
                a, b = fx + dx, fz + dz
                if 0 <= a < nx and 0 <= b < nz and walkable[a, b] and not seen[a, b]:
                    seen[a, b] = True
                    queue.append((a, b))
                    started += 1
        if started == 0:
            bad.append((name, [round(foot[0], 1), FLOOR_Y, round(foot[1], 1)],
                        "the spiral's last tread lands on nothing standable"))
            continue
        while queue:
            x, z = queue.popleft()
            here = floor[x, z]
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = x + dx, z + dz
                if (0 <= a < nx and 0 <= b < nz and walkable[a, b]
                        and not seen[a, b] and abs(floor[a, b] - here) <= STEP):
                    seen[a, b] = True
                    queue.append((a, b))

        for target, (tx, tz) in MUST_REACH:
            gxi, gzi = int((tx - x_lo) / CELL), int((tz - z_lo) / CELL)
            window = seen[max(gxi - 4, 0):gxi + 5, max(gzi - 4, 0):gzi + 5]
            if not window.any():
                # name the frontier: what the flood stopped against
                edge = {}
                xs, zs = np.nonzero(seen)
                for x, z in zip(xs, zs):
                    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        a, b = x + dx, z + dz
                        if 0 <= a < nx and 0 <= b < nz and not walkable[a, b] and owner[a, b]:
                            edge[owner[a, b]] = edge.get(owner[a, b], 0) + 1
                worst = sorted(edge.items(), key=lambda kv: -kv[1])[:3]
                bad.append((name, target,
                            "never reached; the walk stops against "
                            + ", ".join(f"{n} ({c} cells)" for n, c in worst)))
        print(f"  {name:20s} {int(seen.sum()):6d} cells walked from its last tread")

    for row in bad:
        print("  " + "  ".join(str(v) for v in row))
    print(f"{'FAIL' if bad else 'PASS'} - both descents reach the pyramid "
          f"({len(solids)} solids at estate level, from two modules)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
