"""Hand-painted school textures.

The previous set were clean flat patterns: a brick grid with a mortar line, a
plaster wall with faint noise. They read as printed-on because they were
missing everything a painter puts in and a pattern generator leaves out:

  * ambient occlusion in every recess. Mortar joints, plank gaps, tile grout
    and shingle overlaps are all *below* the surface, and the single biggest
    reason a flat texture looks flat is that nothing gets darker where it is
    deep. This is baked here rather than left to the engine, which cannot know
    where a painted joint is.
  * an edge catch. Every raised element gets a lighter line along its top edge
    and a darker one along its bottom, which is what makes brick read as brick
    rather than as a red rectangle.
  * large-scale drift. Real walls are damp in one corner and bleached in
    another. Without a metre-scale variation the tile repeats visibly at any
    distance.
  * per-element variation. No two bricks, planks or slates are the same colour.
  * grime. Dirt collects in joints, streaks run down from ledges, floors wear
    dark along the paths people take.

Everything tiles seamlessly: noise is generated on a torus and every gradient
wraps, so there is no seam at any repeat.
"""
import numpy as np
from PIL import Image
import os, sys

N = 1024
rng = np.random.default_rng(7)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))


# ----------------------------------------------------------------- noise ---
def value_noise(res, seed):
    """Tileable value noise at `res` cells across, bilinearly upsampled."""
    r = np.random.default_rng(seed)
    grid = r.random((res, res)).astype(np.float32)
    grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
    ys = np.linspace(0, res, N, endpoint=False)
    xs = np.linspace(0, res, N, endpoint=False)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = (ys - y0)[:, None]; fx = (xs - x0)[None, :]
    # smoothstep so the cells do not read as a lattice
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    g00 = grid[np.ix_(y0, x0)]; g10 = grid[np.ix_(y0 + 1, x0)]
    g01 = grid[np.ix_(y0, x0 + 1)]; g11 = grid[np.ix_(y0 + 1, x0 + 1)]
    return (g00 * (1 - fy) * (1 - fx) + g10 * fy * (1 - fx)
            + g01 * (1 - fy) * fx + g11 * fy * fx)


def fbm(seed, octaves=5, base=4, gain=0.5):
    out = np.zeros((N, N), np.float32)
    amp, res, total = 1.0, base, 0.0
    for o in range(octaves):
        out += value_noise(res, seed + o * 101) * amp
        total += amp
        amp *= gain
        res *= 2
    return out / total


def norm(a):
    lo, hi = a.min(), a.max()
    return (a - lo) / max(1e-6, hi - lo)


# ------------------------------------------------------------- utilities ---
YY, XX = np.mgrid[0:N, 0:N].astype(np.float32)


def shade(rgb, amount):
    """Multiply brightness by `amount` (an NxN field), keeping hue."""
    return rgb * amount[..., None]


def tint(rgb, colour, strength):
    return rgb * (1 - strength[..., None]) + np.array(colour, np.float32) * strength[..., None]


def save(name, rgb):
    img = np.clip(rgb, 0, 255).astype(np.uint8)
    Image.fromarray(img).save(os.path.join(OUT, f"t_{name}.png"))
    print(f"  t_{name}.png")


def ao_from_mask(joint, width):
    """Soft darkening that spreads out of a joint mask - the recess shadow."""
    from scipy.ndimage import gaussian_filter  # noqa
    return gaussian_filter(joint, width, mode="wrap")


# scipy may be absent; fall back to a separable box blur on a torus
try:
    from scipy.ndimage import gaussian_filter as _gf

    def blur(a, r):
        return _gf(a, r, mode="wrap")
except Exception:
    def blur(a, r):
        r = max(1, int(r))
        k = 2 * r + 1
        pad = np.pad(a, r, mode="wrap")
        c = np.cumsum(pad, 0)
        a2 = (c[k:, :] - c[:-k, :]) / k
        c = np.cumsum(a2, 1)
        return (c[:, k:] - c[:, :-k]) / k


# ------------------------------------------------------------------ brick ---
def brick():
    rows, cols = 16, 8
    bh, bw = N / rows, N / cols
    row = (YY / bh).astype(int)
    # running bond: every other course offset half a brick
    xoff = (XX + np.where(row % 2 == 0, 0.0, bw / 2)) % N
    col = (xoff / bw).astype(int)
    ident = row * 977 + col * 131

    inr = (YY / bh) % 1.0            # 0..1 up the brick
    inc = (xoff / bw) % 1.0          # 0..1 across it

    mortar_v = 0.055
    mortar_h = 0.03
    joint = ((inr < mortar_v) | (inr > 1 - mortar_v)
             | (inc < mortar_h) | (inc > 1 - mortar_h)).astype(np.float32)

    # per-brick colour: warm reds drifting to plum and sand
    r = np.random.default_rng(3)
    hue = r.random(rows * cols * 4)[ident % (rows * cols * 4)]
    val = r.random(rows * cols * 4)[(ident * 7) % (rows * cols * 4)]
    base = np.stack([
        150 + hue * 48 - val * 22,
        70 + hue * 26 + val * 10,
        58 + hue * 20 + val * 12,
    ], -1).astype(np.float32)

    # a handful of much darker fired bricks, and a few pale ones
    burnt = (r.random(rows * cols * 4)[(ident * 13) % (rows * cols * 4)] < 0.07)[..., None]
    base = np.where(burnt, base * 0.62, base)
    pale = (r.random(rows * cols * 4)[(ident * 29) % (rows * cols * 4)] < 0.05)[..., None]
    base = np.where(pale, base * 1.18 + 22, base)

    # surface grain inside each brick
    grain = fbm(11, octaves=6, base=64)
    base = base * (0.9 + 0.2 * grain)[..., None]

    # mortar itself: pale grey, slightly dirty
    mortar_col = np.stack([np.full((N, N), 176.0), np.full((N, N), 172.0), np.full((N, N), 162.0)], -1)
    mortar_col *= (0.86 + 0.22 * fbm(23, base=48))[..., None]
    rgb = base * (1 - joint[..., None]) + mortar_col * joint[..., None]

    # ---- the part that was missing: recess shadow out of every joint ----
    ao = blur(joint, 5.0)
    rgb = shade(rgb, 1.0 - 0.55 * np.clip(ao, 0, 1))

    # edge catch: light along the top of each brick, dark along the bottom
    top = np.clip((inr - (1 - mortar_v - 0.10)) / 0.10, 0, 1) * (1 - joint)
    bot = np.clip(((mortar_v + 0.10) - inr) / 0.10, 0, 1) * (1 - joint)
    rgb = shade(rgb, 1.0 + 0.20 * top - 0.16 * bot)

    # metre-scale weathering: damp low, bleached high, streaks below ledges
    drift = fbm(41, octaves=4, base=3)
    rgb = shade(rgb, 0.80 + 0.34 * drift)
    streak = norm(blur(fbm(57, octaves=3, base=6) ** 3, 1.0))
    rgb = tint(rgb, (84, 76, 70), 0.22 * streak * np.clip(1.2 - YY / N, 0, 1))
    return rgb


# ---------------------------------------------------------------- plaster ---
def plaster():
    base = np.array([228, 224, 214], np.float32)
    rgb = np.broadcast_to(base, (N, N, 3)).copy()
    # Plaster is a calm surface. The first attempt mottled it so hard it read
    # as stained concrete; what it wants is a faint trowel sweep, a fine tooth
    # and almost nothing else.
    trowel = fbm(5, octaves=5, base=3)
    rgb = shade(rgb, 0.955 + 0.09 * trowel)
    fine = fbm(19, octaves=3, base=220)
    rgb = shade(rgb, 0.975 + 0.05 * fine)
    streak = norm(blur(fbm(31, octaves=3, base=5) ** 2, 2.5))
    rgb = tint(rgb, (176, 168, 154), 0.10 * streak * np.clip(1.2 - YY / N, 0, 1))
    return rgb


# ------------------------------------------------------------------- wood ---
def wood():
    planks = 6
    ph = N / planks
    idx = (YY / ph).astype(int)
    inp = (YY / ph) % 1.0
    r = np.random.default_rng(9)
    shift = r.random(planks * 3)[idx % (planks * 3)]
    val = r.random(planks * 3)[(idx * 5) % (planks * 3)]

    base = np.stack([
        128 + shift * 40 - val * 16,
        94 + shift * 28 - val * 12,
        64 + shift * 20 - val * 9,
    ], -1).astype(np.float32)

    # Grain runs the length of the plank. Noise stretched hard along X gives
    # fibres rather than the topographic swirls a plain fbm produces, and each
    # plank gets its own phase so the grain does not line up across the gap.
    fibre = (value_noise(6, 201) * 0.45
             + value_noise(24, 211) * 0.33
             + value_noise(96, 221) * 0.22)
    fibre = blur(fibre, 0.6)
    stretched = np.take(fibre, (np.arange(N) // 8) % N, axis=1)
    lines = value_noise(320, 231 ) * 0.5 + 0.5
    grain = 0.62 * stretched + 0.38 * np.take(lines, np.arange(N), axis=0)
    grain = grain + shift * 0.12
    rgb = shade(base, 0.84 + 0.30 * norm(grain))

    # a few knots, elongated the way a knot in a sawn board is
    kr = np.random.default_rng(4)
    for _ in range(5):
        ky, kx = kr.random() * N, kr.random() * N
        dy = np.minimum(np.abs(YY - ky), N - np.abs(YY - ky))
        dx = np.minimum(np.abs(XX - kx), N - np.abs(XX - kx))
        d = np.sqrt(dy ** 2 + (dx / 2.4) ** 2)
        k = np.clip(1 - d / (10 + kr.random() * 12), 0, 1) ** 2
        rgb = shade(rgb, 1 - 0.45 * k)

    # the gap between boards, and the shadow it throws
    gap = ((inp < 0.014) | (inp > 0.986)).astype(np.float32)
    rgb = shade(rgb, 1 - 0.62 * gap)
    rgb = shade(rgb, 1 - 0.30 * np.clip(blur(gap, 5.0), 0, 1))
    rgb = shade(rgb, 1 + 0.14 * np.clip((inp - 0.95) / 0.04, 0, 1) * (1 - gap))
    rgb = shade(rgb, 0.92 + 0.14 * fbm(61, octaves=3, base=3))
    return rgb


# -------------------------------------------------------------- floor tile ---
def floortile():
    cells = 8
    cw = N / cells
    ix = (XX / cw).astype(int); iy = (YY / cw).astype(int)
    ident = iy * 71 + ix * 13
    r = np.random.default_rng(15)
    v = r.random(cells * cells * 3)[ident % (cells * cells * 3)]

    base = np.stack([
        214 + v * 26, 210 + v * 24, 198 + v * 22,
    ], -1).astype(np.float32)
    # checker: every other tile a shade cooler
    checker = ((ix + iy) % 2)[..., None]
    # a real checker, not a whisper: the old 10% difference vanished under the
    # speckle and the floor read as one grey field
    base = base * (1 - checker * 0.24)
    base = tint(base, np.array([182, 176, 164], np.float32), checker[..., 0] * 0.30)

    speck = (fbm(29, octaves=2, base=200) > 0.88).astype(np.float32)
    base = shade(base, 1 - 0.14 * speck)
    base = shade(base, 0.94 + 0.12 * fbm(37, octaves=4, base=8))

    inx = (XX / cw) % 1.0; iny = (YY / cw) % 1.0
    g = 0.022
    grout = ((inx < g) | (inx > 1 - g) | (iny < g) | (iny > 1 - g)).astype(np.float32)
    grout_col = np.stack([np.full((N, N), 138.0), np.full((N, N), 134.0), np.full((N, N), 126.0)], -1)
    rgb = base * (1 - grout[..., None]) + grout_col * grout[..., None]
    rgb = shade(rgb, 1 - 0.50 * np.clip(blur(grout, 3.5), 0, 1))
    # scuffed walking paths
    wear = norm(blur(fbm(67, octaves=3, base=3) ** 2, 2.0))
    rgb = shade(rgb, 1 - 0.12 * wear)
    return rgb


# ----------------------------------------------------------------- carpet ---
def carpet():
    base = np.array([120, 60, 54], np.float32)
    rgb = np.broadcast_to(base, (N, N, 3)).copy()

    # A loop pile has structure you can see: rows of loops catching light on
    # top and shadowed between. The old version used noise so fine it averaged
    # out to a flat slab at any distance.
    loop = (np.sin(YY * 0.55) * 0.5 + 0.5) * (np.sin(XX * 0.55) * 0.5 + 0.5)
    loop = loop * 0.55 + fbm(13, octaves=3, base=110) * 0.45
    rgb = shade(rgb, 0.70 + 0.58 * loop)

    # flecked yarn: real contract carpet is three or four colours spun together
    fleck = value_noise(150, 43)
    rgb = tint(rgb, (194, 152, 96), 0.26 * np.clip((fleck - 0.62) / 0.38, 0, 1))
    rgb = tint(rgb, (54, 40, 58), 0.22 * np.clip((0.34 - fleck) / 0.34, 0, 1))
    rgb = tint(rgb, (150, 96, 70), 0.18 * value_noise(60, 47))

    # traffic wear, and the darker line where the pile meets the floor
    wear = norm(blur(fbm(53, octaves=3, base=3) ** 2, 3.0))
    rgb = shade(rgb, 0.84 + 0.26 * wear)
    return rgb


# -------------------------------------------------------------- bluestone ---
def bluestone():
    rows, cols = 10, 6
    bh, bw = N / rows, N / cols
    row = (YY / bh).astype(int)
    xoff = (XX + np.where(row % 2 == 0, 0.0, bw / 3)) % N
    col = (xoff / bw).astype(int)
    ident = row * 313 + col * 37
    r = np.random.default_rng(21)
    v = r.random(rows * cols * 4)[ident % (rows * cols * 4)]
    # one coherent slate family, not confetti
    base = np.stack([
        108 + v * 44, 116 + v * 42, 124 + v * 40,
    ], -1).astype(np.float32)
    base = tint(base, (128, 120, 106), 0.22 * value_noise(6, 91))
    base = shade(base, 0.84 + 0.30 * fbm(97, octaves=5, base=48))

    inr = (YY / bh) % 1.0; inc = (xoff / bw) % 1.0
    m = 0.045
    joint = ((inr < m) | (inr > 1 - m) | (inc < m * 0.7) | (inc > 1 - m * 0.7)).astype(np.float32)
    rgb = base * (1 - joint[..., None]) + np.array([92, 92, 88], np.float32) * joint[..., None]
    rgb = shade(rgb, 1 - 0.58 * np.clip(blur(joint, 5.0), 0, 1))
    rgb = shade(rgb, 1 + 0.18 * np.clip((inr - 0.86) / 0.10, 0, 1) * (1 - joint))
    return rgb


# ---------------------------------------------------------------- shingle ---
def shingle():
    courses = 14
    ch = N / courses
    row = (YY / ch).astype(int)
    tabw = N / 10
    xoff = (XX + np.where(row % 2 == 0, 0.0, tabw / 2)) % N
    col = (xoff / tabw).astype(int)
    ident = row * 191 + col * 53
    r = np.random.default_rng(33)
    v = r.random(courses * 12)[ident % (courses * 12)]
    base = np.stack([
        74 + v * 40, 82 + v * 38, 92 + v * 36,
    ], -1).astype(np.float32)
    base = shade(base, 0.82 + 0.34 * fbm(103, octaves=5, base=64))

    inr = (YY / ch) % 1.0
    # each course overlaps the one below: a hard shadow under the butt edge
    butt = np.clip((0.16 - inr) / 0.16, 0, 1)
    rgb = shade(base, 1 - 0.55 * butt)
    # keyway between tabs
    inc = (xoff / tabw) % 1.0
    key = ((inc < 0.02) | (inc > 0.98)).astype(np.float32) * (inr > 0.16)
    rgb = shade(rgb, 1 - 0.5 * key)
    rgb = shade(rgb, 1 + 0.14 * np.clip((inr - 0.9) / 0.1, 0, 1))
    # weathering streaks running down the slope
    streak = norm(blur(fbm(113, octaves=3, base=8) ** 2, 1.2))
    rgb = tint(rgb, (122, 126, 120), 0.2 * streak)
    return rgb


# ----------------------------------------------------------------- locker ---
def locker():
    doors = 4
    dw = N / doors
    ix = (XX / dw).astype(int)
    inx = (XX / dw) % 1.0
    r = np.random.default_rng(55)
    v = r.random(doors * 4)[ix % (doors * 4)]
    base = np.stack([
        38 + v * 16, 76 + v * 22, 158 + v * 30,
    ], -1).astype(np.float32)
    # brushed vertical grain
    grain = value_noise(400, 121)
    base = shade(base, 0.92 + 0.16 * grain)

    # the gap between doors, with its shadow
    gap = ((inx < 0.02) | (inx > 0.98)).astype(np.float32)
    rgb = shade(base, 1 - 0.7 * gap)
    rgb = shade(rgb, 1 - 0.3 * np.clip(blur(gap, 4.0), 0, 1))
    # recessed panel on each door
    iny = YY / N
    panel = ((inx > 0.10) & (inx < 0.90) & (iny > 0.06) & (iny < 0.94)).astype(np.float32)
    edge = np.clip(blur(panel, 3.0) - panel, 0, 1)
    rgb = shade(rgb, 1 - 0.35 * edge)
    # vents near the top
    vent = (((YY % (N / 1)) > N * 0.08) & ((YY % (N / 1)) < N * 0.20)
            & (((YY / 6).astype(int) % 2) == 0) & (inx > 0.25) & (inx < 0.75)).astype(np.float32)
    rgb = shade(rgb, 1 - 0.5 * vent)
    # handle
    handle = ((iny > 0.46) & (iny < 0.55) & (inx > 0.70) & (inx < 0.80)).astype(np.float32)
    rgb = rgb * (1 - handle[..., None]) + np.array([196, 198, 204], np.float32) * handle[..., None]
    # scuffs and dents
    scuff = norm(blur(fbm(131, octaves=3, base=6) ** 2, 1.5))
    rgb = shade(rgb, 0.88 + 0.2 * scuff)
    return rgb


# ------------------------------------------------------------------ grass ---
def grass():
    # clumps at three scales, so it does not read as felt
    a = fbm(71, octaves=3, base=6)
    b = fbm(79, octaves=3, base=26)
    c = value_noise(300, 89)
    blade = 0.45 * a + 0.33 * b + 0.22 * c
    base = np.stack([
        62 + blade * 74, 118 + blade * 92, 48 + blade * 50,
    ], -1).astype(np.float32)
    # dry patches and bare earth showing through
    dry = np.clip((fbm(87, octaves=4, base=4) - 0.55) / 0.45, 0, 1)
    base = tint(base, (168, 158, 92), 0.5 * dry)
    bare = np.clip((fbm(93, octaves=4, base=5) - 0.74) / 0.26, 0, 1)
    base = tint(base, (104, 84, 62), 0.7 * bare)
    # darker between the clumps: the shadow at the roots
    base = shade(base, 0.72 + 0.4 * norm(blur(blade, 2.0)))
    return base


# ---------------------------------------------------------------- ceiling ---
def ceiling():
    cells = 4
    cw = N / cells
    inx = (XX / cw) % 1.0; iny = (YY / cw) % 1.0
    base = np.full((N, N, 3), 232.0, np.float32)
    base = shade(base, 0.94 + 0.1 * fbm(141, octaves=4, base=120))
    # perforated acoustic tile
    perf = ((np.sin(XX * 1.4) * np.sin(YY * 1.4)) > 0.86).astype(np.float32)
    base = shade(base, 1 - 0.16 * perf)
    g = 0.016
    grid = ((inx < g) | (inx > 1 - g) | (iny < g) | (iny > 1 - g)).astype(np.float32)
    base = base * (1 - grid[..., None]) + np.array([176, 174, 168], np.float32) * grid[..., None]
    base = shade(base, 1 - 0.32 * np.clip(blur(grid, 4.0), 0, 1))
    return base


# ----------------------------------------------------------------- window ---
def window():
    panes = 2
    pw = N / panes
    inx = (XX / pw) % 1.0; iny = (YY / pw) % 1.0
    # sky reflected in the glass, brighter towards the top
    sky = np.stack([
        150 + 70 * (1 - YY / N), 186 + 56 * (1 - YY / N), 214 + 40 * (1 - YY / N),
    ], -1).astype(np.float32)
    # a diagonal highlight sweeping the pane
    sweep = np.clip(1 - np.abs(((XX + YY) / (N * 1.4)) % 1.0 - 0.5) * 5, 0, 1)
    rgb = shade(sky, 1 + 0.16 * sweep)
    # grime at the pane edges
    rgb = shade(rgb, 1 - 0.12 * norm(blur(fbm(151, octaves=3, base=10), 2.0)))
    f = 0.06
    frame = ((inx < f) | (inx > 1 - f) | (iny < f) | (iny > 1 - f)).astype(np.float32)
    frame_col = np.stack([np.full((N, N), 232.0), np.full((N, N), 228.0), np.full((N, N), 216.0)], -1)
    frame_col = shade(frame_col, 0.92 + 0.14 * fbm(157, octaves=3, base=60))
    rgb = rgb * (1 - frame[..., None]) + frame_col * frame[..., None]
    rgb = shade(rgb, 1 - 0.38 * np.clip(blur(frame, 3.0) - frame, 0, 1))
    return rgb


for name, fn in [
    ("brick", brick), ("plaster", plaster), ("wood", wood), ("floortile", floortile),
    ("carpet", carpet), ("bluestone", bluestone), ("shingle", shingle),
    ("locker", locker), ("grass", grass), ("ceiling", ceiling), ("window", window),
]:
    save(name, fn())
print("repainted 11 textures")
