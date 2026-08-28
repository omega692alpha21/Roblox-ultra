#!/usr/bin/env python3
"""Measure how much light actually lands on the ground, and fail where it piles up.

The night look went out with 38 lamp posts at brightness 2.2 and range 48, plus
a light in every third window, plus everything that was already there. Roblox's
Future lighting ADDS overlapping point lights, and the screenshot that came
back was a white-out: the grass read as bright yellow, the facade as a glare,
and none of the detail that had just been built was visible at all.

Guessing new numbers and looking again is how the last several passes of this
went. Instead this sums the contribution of every light at a grid of points at
eye height and reports the distribution, so the tuning has a number behind it.

Falloff is modelled as brightness * (1 - d/range)^2, which is close enough to
what Roblox does for the purpose of asking "is anywhere getting ten times what
it needs".

    python3 tools/render_map.py . tools && python3 tools/glare_check.py
"""
import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Above this, a surface is washed out: the material stops reading and
# everything converges on white.
HOT = 3.0
STEP = 12.0
EYE = 5.0


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    parts = json.load(open(os.path.join(out, "_map_export.json")))
    lights = [(p["p"], r, b) for p in parts for r, b in p.get("lamps", [])]
    if not lights:
        print("no lights in the dump; re-run render_map.py")
        return 1

    xs = [p["p"][0] for p in parts]
    zs = [p["p"][2] for p in parts]
    x0, x1 = max(min(xs), -600), min(max(xs), 620)
    z0, z1 = max(min(zs), -460), min(max(zs), 600)

    # index the lights so this is not 261 x 40,000
    CELL = 64.0
    grid = {}
    for pos, r, b in lights:
        for cx in range(int((pos[0] - r) // CELL), int((pos[0] + r) // CELL) + 1):
            for cz in range(int((pos[2] - r) // CELL), int((pos[2] + r) // CELL) + 1):
                grid.setdefault((cx, cz), []).append((pos, r, b))

    samples, hot, peak, peak_at = [], 0, 0.0, None
    x = x0
    while x <= x1:
        z = z0
        while z <= z1:
            total = 0.0
            for pos, r, b in grid.get((int(x // CELL), int(z // CELL)), ()):
                d = math.sqrt((pos[0] - x) ** 2 + (pos[1] - EYE) ** 2 + (pos[2] - z) ** 2)
                if d < r:
                    f = 1.0 - d / r
                    total += b * f * f
            samples.append(total)
            if total > HOT:
                hot += 1
            if total > peak:
                peak, peak_at = total, (round(x), round(z))
            z += STEP
        x += STEP

    samples.sort()
    n = len(samples)
    def pct(q):
        return samples[min(n - 1, int(n * q))]

    # Bloom does not care about point lights; it cares about how much of the
    # screen is emitting. That is what washed the last build out, so it is
    # counted here rather than left to be discovered in a screenshot.
    neon = [p for p in parts if p["m"] == "Neon" and p["t"] < 0.6]
    area = sum(2 * (p["s"][0] * p["s"][1] + p["s"][1] * p["s"][2] + p["s"][0] * p["s"][2])
               for p in neon)
    print(f"{len(lights)} lights, {n} ground samples")
    print(f"  {len(neon)} emissive surfaces, {area:,.0f} square studs of neon")
    print(f"  median {pct(0.5):.2f}   p90 {pct(0.90):.2f}   p99 {pct(0.99):.2f}   peak {peak:.2f} at {peak_at}")
    print(f"  {hot} samples ({100.0 * hot / n:.1f}%) over the {HOT:.1f} wash-out line")
    if pct(0.99) > HOT:
        print(f"FAIL - the top 1% of the ground is over {HOT:.1f}; the scene will read as glare")
        return 1
    print("PASS - light stays under the wash-out line")
    return 0


if __name__ == "__main__":
    sys.exit(main())
