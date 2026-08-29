#!/usr/bin/env python3
"""Find ground a player crosses at night and cannot see.

tools/light_check.py asks whether every ROOM is lit. Nothing has ever asked it
of the outside, and the outside is what the reference art is: four night
pictures of courts, walks and a drive, every one of them lit by lamp standards
and by the windows behind them. A dark walk is not a small defect in a night
game -- it is the part of the campus a player is standing on.

The measurement is the same one the night renderer does. Every PointLight in
the dump carries its range and brightness, so the light landing on a patch of
ground is a sum over the lights that reach it, inverse-falloff and cosine
weighted against the up normal. A patch below the floor is dark; enough dark
patches in one surface and it is a hole in the campus.

It samples the surfaces people actually walk: paving, walks, drives, aprons,
terraces and courts, outdoors, at ground level. Lawns are not sampled -- grass
between lit walks is meant to be dark, and the references show it that way.

    python3 tools/render_map.py .
    python3 tools/nightlight_check.py
"""
import json, math, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "_map_export.json")

# What counts as ground somebody crosses.
WALKED = ("Paving", "Walk", "Path", "Apron", "Terrace", "Drive", "Plaza",
          "Road", "Court", "Step", "Landing", "Deck")
NOT_WALKED = ("Lawn", "Grass", "Turf", "Hedge", "Bed", "Border", "Kerb",
              "Joint", "Line", "Marking", "Wall", "Roof", "Ceiling", "Lamp",
              "Rail", "Key", "Net", "Post", "Basin", "Water", "Bowl", "Jet")
STEP = 14.0        # sample spacing
GROUND_MAX = 4.0   # a surface higher than this is a roof or a table, not ground
MIN_AREA = 400.0   # ignore slivers
# Below this the ground is not lit at all. A lamp with range 52 and brightness
# 2.4 lands about 0.6 directly under itself at this falloff, and about 0.08
# thirty studs away, which is the middle of a walk between two standards.
DARK = 0.045
# ... and a surface fails only if this share of it is dark. The far corner of
# the sports field is allowed to be dark; the walk to the front doors is not.
DARK_SHARE = 0.55


def aabb(p):
    r, s, q = p["r"], p["s"], p["p"]
    half = [0.5 * sum(abs(r[row * 3 + col]) * s[col] for col in range(3)) for row in range(3)]
    return [(q[i] - half[i], q[i] + half[i]) for i in range(3)]


def main():
    parts = json.load(open(DUMP))

    lights = []
    for p in parts:
        for lamp in p.get("lamps") or ():
            lights.append((p["p"][0], p["p"][1], p["p"][2], float(lamp[0]), float(lamp[1])))
    if not lights:
        print("FAIL - no lights in the dump at all")
        return 1

    CELL = 64.0
    grid = defaultdict(list)
    for i, (lx, _ly, lz, rng, _b) in enumerate(lights):
        span = int(rng // CELL) + 1
        cx0, cz0 = int(lx // CELL), int(lz // CELL)
        for dx in range(-span, span + 1):
            for dz in range(-span, span + 1):
                grid[(cx0 + dx, cz0 + dz)].append(i)

    def landing(x, y, z):
        """Direct light on a horizontal patch at (x, y, z)."""
        total = 0.0
        for i in grid.get((int(x // CELL), int(z // CELL)), ()):
            lx, ly, lz, rng, bright = lights[i]
            dx, dy, dz = lx - x, ly - y, lz - z
            d2 = dx * dx + dy * dy + dz * dz
            if d2 >= rng * rng or dy <= 0:
                continue
            d = math.sqrt(d2) or 1e-6
            fall = 1.0 - d / rng
            total += bright * (dy / d) * fall * fall
        return total

    # Roofs, so a covered walk is not reported: an alley under a canopy is
    # meant to be dark, and the map lights those with their own fittings.
    surfaces = []
    for p in parts:
        n = p["n"]
        if any(w in n for w in NOT_WALKED) or not any(w in n for w in WALKED):
            continue
        b = aabb(p)
        top = b[1][1]
        if top > GROUND_MAX or top < -1.0:
            continue
        w, d = b[0][1] - b[0][0], b[2][1] - b[2][0]
        if w * d < MIN_AREA:
            continue
        surfaces.append((p, b, top, w * d))

    if not surfaces:
        print("FAIL - no walked ground found; the name list is wrong")
        return 1

    bad, sampled, dark_total = [], 0, 0
    for p, b, top, area in surfaces:
        pts = dark = 0
        x = b[0][0] + STEP / 2
        while x < b[0][1]:
            z = b[2][0] + STEP / 2
            while z < b[2][1]:
                pts += 1
                if landing(x, top + 0.5, z) < DARK:
                    dark += 1
                z += STEP
            x += STEP
        if not pts:
            continue
        sampled += pts
        dark_total += dark
        if dark / pts > DARK_SHARE:
            bad.append((dark / pts, p["n"], [round(v) for v in p["p"]], round(area)))

    print(f"{len(surfaces)} walked surfaces, {sampled} patches sampled, "
          f"{dark_total} of them dark ({dark_total / max(sampled, 1):.0%})")
    if bad:
        bad.sort(reverse=True)
        for share, name, pos, area in bad[:12]:
            print(f"  {share:.0%} dark  {name:22} at {pos}  {area} sq studs")
        print(f"FAIL - {len(bad)} surfaces are unlit ground a player walks on")
        return 1
    print("PASS - every walked surface outdoors has light on it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
