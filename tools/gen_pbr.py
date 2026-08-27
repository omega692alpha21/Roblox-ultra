"""Derive normal + roughness maps from the hand-painted albedos.

Roblox's PBR pipeline lights a surface off its normal map, which is what turns
a flat painted texture into something that catches the sun. We have no
sculpted height data, so the normals come from the albedo's own luminance:
painted mortar lines, plank gaps and fabric weave are all darker than what
surrounds them, so treating luminance as height reads the relief the painting
already implies.

Roughness comes from the same signal, inverted and biased per material: paint
and plaster scatter light, glass and tile do not.
"""
import numpy as np
from PIL import Image, ImageFilter
import pathlib, sys

SRC = pathlib.Path(sys.argv[1])
OUT = SRC / "pbr"
OUT.mkdir(exist_ok=True)

# per-material: how deep the relief reads, and the roughness window it maps into
PROFILE = {
    "brick":     dict(depth=3.2, rough=(0.62, 0.95)),
    "bluestone": dict(depth=2.8, rough=(0.55, 0.88)),
    "plaster":   dict(depth=1.4, rough=(0.70, 0.94)),
    "wood":      dict(depth=2.0, rough=(0.42, 0.74)),
    "floortile": dict(depth=1.6, rough=(0.22, 0.52)),
    "carpet":    dict(depth=2.6, rough=(0.86, 0.99)),
    "ceiling":   dict(depth=1.2, rough=(0.74, 0.93)),
    "locker":    dict(depth=2.2, rough=(0.30, 0.58)),
    "shingle":   dict(depth=3.6, rough=(0.66, 0.92)),
    "grass":     dict(depth=2.4, rough=(0.80, 0.98)),
    "window":    dict(depth=1.0, rough=(0.06, 0.26)),
}

def luminance(img):
    a = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]

def normal_map(height, depth):
    # wrap the gradients so the map tiles as seamlessly as the albedo does
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * depth
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * depth
    nz = np.ones_like(height)
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    # OpenGL convention: +Y up, which is what Roblox expects
    r = (-dx / length * 0.5 + 0.5)
    g = (dy / length * 0.5 + 0.5)
    b = (nz / length * 0.5 + 0.5)
    return np.dstack([r, g, b])

for path in sorted(SRC.glob("t_*.png")):
    key = path.stem[2:]
    prof = PROFILE.get(key)
    if not prof:
        continue
    img = Image.open(path)
    # a light blur first: we want the painted forms, not the canvas grain
    height = luminance(img.filter(ImageFilter.GaussianBlur(1.1)))

    nrm = (normal_map(height, prof["depth"]) * 255).clip(0, 255).astype(np.uint8)
    Image.fromarray(nrm).save(OUT / f"n_{key}.png")

    lo, hi = prof["rough"]
    # darker paint = more broken up = rougher
    rough = (1.0 - height)
    rough = (rough - rough.min()) / max(1e-5, rough.max() - rough.min())
    rough = lo + rough * (hi - lo)
    rough8 = (rough * 255).clip(0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([rough8] * 3)).save(OUT / f"r_{key}.png")
    print(f"  {key:10s} depth {prof['depth']:.1f}  rough {lo:.2f}-{hi:.2f}")

print(f"wrote {len(list(OUT.glob('*.png')))} maps to {OUT}")
