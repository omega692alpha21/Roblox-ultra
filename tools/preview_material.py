#!/usr/bin/env python3
"""Light a material the way the engine will, so it can be judged before upload.

Roblox lights a surface from its normal map. A texture that looks right flat
can still read as wallpaper in game if the normals carry no relief, and there
is no way to tell by looking at the albedo. This does the same lambert +
specular the engine does, from a low sun, which is the case that shows relief.

    python3 tools/preview_material.py <art_dir> <out.png>
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import sys, os

ART = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else "material_preview.png"
NAMES = ["brick", "plaster", "wood", "floortile", "carpet",
         "bluestone", "shingle", "locker", "grass", "ceiling"]

# a low sun raking across the surface: the angle that reveals relief
L = np.array([-0.55, 0.42, 0.72], np.float32)
L /= np.linalg.norm(L)
V = np.array([0.0, 0.0, 1.0], np.float32)
H = (L + V) / np.linalg.norm(L + V)

TILE = 300
cols = 5
rows = (len(NAMES) + cols - 1) // cols
sheet = Image.new("RGB", (cols * TILE, rows * (TILE + 22)), (16, 16, 20))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
except Exception:
    font = None

for i, name in enumerate(NAMES):
    alb = np.asarray(Image.open(f"{ART}/t_{name}.png").convert("RGB"), np.float32) / 255.0
    npath = f"{ART}/pbr/n_{name}.png"
    rpath = f"{ART}/pbr/r_{name}.png"
    if os.path.exists(npath):
        nrm = np.asarray(Image.open(npath).convert("RGB"), np.float32) / 255.0 * 2 - 1
        nrm /= np.maximum(1e-6, np.linalg.norm(nrm, axis=2, keepdims=True))
    else:
        nrm = np.zeros_like(alb); nrm[..., 2] = 1
    rough = (np.asarray(Image.open(rpath).convert("L"), np.float32) / 255.0
             if os.path.exists(rpath) else np.full(alb.shape[:2], 0.7, np.float32))

    ndl = np.clip(nrm @ L, 0, 1)
    ndh = np.clip(nrm @ H, 0, 1)
    # a rough surface spreads its highlight; a smooth one keeps it tight
    power = np.clip(2.0 / np.maximum(rough, 0.05) ** 2, 2, 400)
    spec = (1.0 - rough) * ndh ** power

    lit = alb * (0.34 + 0.78 * ndl[..., None]) + spec[..., None] * 0.55
    lit = np.clip(lit, 0, 1) ** (1 / 1.05)
    img = Image.fromarray((lit * 255).astype(np.uint8)).resize((TILE, TILE))

    x = (i % cols) * TILE
    y = (i // cols) * (TILE + 22)
    sheet.paste(img, (x, y + 22))
    draw.text((x + 6, y + 3), name, font=font, fill=(232, 232, 214))

sheet.save(OUT)
print(f"wrote {OUT}")
