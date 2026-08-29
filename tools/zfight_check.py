#!/usr/bin/env python3
"""Find surfaces that share a plane, because those flicker.

The lobby's wayfinding stripes were laid at exactly the height of the carpet
they cross -- both 0.16-thick slabs centred at y 0.2 -- so the two fought for
the same pixels and the floor flickered in coloured bands. Nothing else in the
suite could see it: the parts are not buried, not floating, not blocking
anything. They are just in the same place.

This looks for pairs of thin, broad parts whose faces land within a hair of
each other and whose footprints overlap, which is exactly the condition a depth
buffer cannot resolve.

    python3 tools/render_map.py . tools && python3 tools/zfight_check.py
"""
import json, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
SAME = 0.02      # closer than this and the GPU cannot separate them
MIN_AREA = 12.0  # a tiny coplanar detail is not what anyone will notice
CELL = 48.0


def footprint(p):
    """The part's actual four corners in plan, not its bounding box.

    The running track is a ring of ROTATED chord segments, and an axis-aligned
    box round a rotated rectangle is much bigger than the rectangle. Measured
    that way every segment appeared to overlap its neighbours and the check
    reported 136 flickering pairs on a track that has none. A tool that cries
    wolf gets ignored, so the plan test uses the real quadrilateral.
    """
    r, s_, q = p["r"], p["s"], p["p"]
    hx, hz = s_[0] / 2, s_[2] / 2
    out = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = sx * hx, sz * hz
        out.append((q[0] + r[0] * lx + r[2] * lz, q[2] + r[6] * lx + r[8] * lz))
    return out


def _signed_area(poly):
    total = 0.0
    for i in range(len(poly)):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % len(poly)]
        total += x0 * z1 - x1 * z0
    return total / 2.0


def _clockwise(poly):
    return poly if _signed_area(poly) < 0 else list(reversed(poly))


def overlap_area(a, b):
    """Sutherland-Hodgman clip of one convex quad by the other, then shoelace.

    Winding matters and is not guaranteed: the inside test below assumes a
    CLOCKWISE clip polygon, and a part's corners come out counter-clockwise, so
    the first version of this returned zero for every pair and the check
    reported a confident PASS over 309 real flickering surfaces. Both polygons
    are put the same way round before anything is clipped.
    """
    a, b = _clockwise(a), _clockwise(b)
    poly = a
    for i in range(len(b)):
        cx, cz = b[i]
        nx, nz = b[(i + 1) % len(b)]
        ex, ez = nx - cx, nz - cz
        clipped = []
        for j in range(len(poly)):
            px, pz = poly[j]
            qx, qz = poly[(j + 1) % len(poly)]
            dp = ex * (pz - cz) - ez * (px - cx)
            dq = ex * (qz - cz) - ez * (qx - cx)
            if dp <= 0:
                clipped.append((px, pz))
            if (dp <= 0) != (dq <= 0):
                t = dp / (dp - dq) if dp != dq else 0.0
                clipped.append((px + (qx - px) * t, pz + (qz - pz) * t))
        poly = clipped
        if not poly:
            return 0.0
    return abs(_signed_area(poly))


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    h = [0.5 * sum(abs(r[i * 3 + j]) * s[j] for j in range(3)) for i in range(3)]
    return [(q[i] - h[i], q[i] + h[i]) for i in range(3)]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    parts = json.load(open(os.path.join(out, "_map_export.json")))

    # Any thin panel, on any axis -- not just floors.
    #
    # This looked only for things thin in Y, so it checked the floors and the
    # roofs and nothing else. Walls z-fight exactly as readily, and the dorm
    # porch had two vertical surfaces speckling against each other that this
    # tool reported as clean. A part is a panel if it is thin on ANY axis, and
    # the pair only matters if they are thin on the SAME axis.
    flats = []
    for p in parts:
        if p["t"] >= 0.9:
            continue
        b = aabb(p)
        span = [b[i][1] - b[i][0] for i in range(3)]
        axis = min(range(3), key=lambda i: span[i])
        if span[axis] > 1.6:
            continue
        face = [i for i in range(3) if i != axis]
        area = span[face[0]] * span[face[1]]
        if area < MIN_AREA:
            continue
        flats.append((p, b, axis, area))

    grid = defaultdict(list)
    for item in flats:
        b = item[1]
        for cx in range(int(b[0][0] // CELL), int(b[0][1] // CELL) + 1):
            for cz in range(int(b[2][0] // CELL), int(b[2][1] // CELL) + 1):
                grid[(cx, cz)].append(item)

    seen, bad = set(), []
    for cell in grid.values():
        for i, (pa, ba, axa, aa) in enumerate(cell):
            for pb, bb, axb, ab in cell[i + 1:]:
                if axa != axb:
                    continue
                key = (id(pa), id(pb))
                if key in seen:
                    continue
                seen.add(key)
                ax = axa
                if not any(abs(ba[ax][u] - bb[ax][v]) < SAME for u in (0, 1) for v in (0, 1)):
                    continue
                face = [i for i in range(3) if i != ax]
                laps = [min(ba[f][1], bb[f][1]) - max(ba[f][0], bb[f][0]) for f in face]
                if laps[0] <= 0.2 or laps[1] <= 0.2:
                    continue
                if ax == 1:
                    # horizontal: use the real oriented footprints, because an
                    # axis-aligned box round a rotated rectangle is much bigger
                    # than the rectangle and the running track showed 136 pairs
                    # it does not have
                    area = overlap_area(footprint(pa), footprint(pb))
                else:
                    area = laps[0] * laps[1]
                if area < MIN_AREA:
                    continue
                bad.append((pa["n"], pb["n"], round(area), [round(v) for v in pa["p"]]))

    # Ranked by AREA, not by how many pairs a name makes.
    #
    # Sorted by count, the worst thing on the campus was invisible: the upper
    # floor's ceiling shared a plane with the floor above it across nearly
    # sixty thousand square studs, and that is ONE pair per slab, so it sat
    # below a dozen names that each make a handful of tiny ones. What a person
    # sees flickering is area.
    counts = defaultdict(lambda: [0, 0.0, None])
    for a, b, area, at in bad:
        pair = tuple(sorted((a, b)))
        counts[pair][0] += 1
        counts[pair][1] += area
        if counts[pair][2] is None:
            counts[pair][2] = at

    print(f"{len(flats)} panels checked on all three axes")
    if not bad:
        print("PASS - nothing shares a plane")
        return 0
    total = sum(v[1] for v in counts.values())
    for pair, (n, area, at) in sorted(counts.items(), key=lambda kv: -kv[1][1])[:15]:
        print(f"  {area:10,.0f} sq studs  {n:4d}x  {pair[0]} / {pair[1]}  e.g. at {at}")
    print(f"  {total:,.0f} square studs of surface fighting in total")
    print(f"FAIL - {len(bad)} overlapping coplanar pairs; these flicker")
    return 1


def self_test():
    """Run before every check. A geometry helper that quietly returns zero is
    indistinguishable from a clean map, and that is how this tool first
    reported PASS over 309 flickering surfaces."""
    unit = [(0, 0), (10, 0), (10, 10), (0, 10)]
    shifted = [(5, 5), (15, 5), (15, 15), (5, 15)]
    apart = [(50, 50), (60, 50), (60, 60), (50, 60)]
    for label, got, want in (
        ("overlapping", overlap_area(unit, shifted), 25.0),
        ("reversed winding", overlap_area(unit, list(reversed(shifted))), 25.0),
        ("identical", overlap_area(unit, unit), 100.0),
        ("disjoint", overlap_area(unit, apart), 0.0),
    ):
        if abs(got - want) > 1e-6:
            print(f"SELF-TEST FAILED: {label} gave {got}, expected {want}")
            return False
    return True


if __name__ == "__main__":
    if not self_test():
        sys.exit(2)
    sys.exit(main())
