"""Turn a Poly Haven CC0 HDRI into a Roblox skybox.

The sky was a flat Roblox default with a Clouds instance over it. A real
captured sky is the cheapest large improvement available to an outdoor scene:
it sets the colour of everything the environment map touches, and Future
lighting reads it for ambient.

Poly Haven ships a tonemapped equirectangular JPEG alongside the HDR, which is
exactly what a skybox wants -- Roblox's Sky takes six LDR faces, not an HDR.
The projection is done here rather than at runtime because Sky.SkyboxUp is a
content property: it needs six uploaded images.

Face axes follow the usual cubemap convention, with Roblox's -Z as front.
"""
import argparse, os, subprocess

import numpy as np
from PIL import Image, ImageFilter

API = "https://api.polyhaven.com"

# name -> (right, up, forward) in Roblox axes. Forward points out of the face.
FACES = {
    "Rt": ((0, 0, 1), (0, -1, 0), (1, 0, 0)),
    "Lf": ((0, 0, -1), (0, -1, 0), (-1, 0, 0)),
    "Up": ((1, 0, 0), (0, 0, 1), (0, 1, 0)),
    "Dn": ((1, 0, 0), (0, 0, -1), (0, -1, 0)),
    "Ft": ((1, 0, 0), (0, -1, 0), (0, 0, -1)),
    "Bk": ((-1, 0, 0), (0, -1, 0), (0, 0, 1)),
}


def fetch(url: str, dest: str) -> str:
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return dest
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    subprocess.run(["curl", "-sS", "-L", "--max-time", "600", "-o", dest, url], check=True)
    return dest


def faces(equirect: Image.Image, size: int) -> dict:
    source = np.asarray(equirect.convert("RGB"), dtype=np.float32)
    height, width, _ = source.shape

    # pixel centres across the face, in [-1, 1]
    axis = (np.arange(size, dtype=np.float32) + 0.5) / size * 2.0 - 1.0
    gx, gy = np.meshgrid(axis, axis)

    out = {}
    for name, (right, up, forward) in FACES.items():
        right = np.array(right, dtype=np.float32)
        up = np.array(up, dtype=np.float32)
        forward = np.array(forward, dtype=np.float32)
        d = (forward[None, None, :]
             + gx[..., None] * right[None, None, :]
             + gy[..., None] * up[None, None, :])
        d /= np.linalg.norm(d, axis=2, keepdims=True)

        # equirectangular lookup: longitude around Y, latitude from Y
        lon = np.arctan2(d[..., 0], -d[..., 2])
        lat = np.arcsin(np.clip(d[..., 1], -1.0, 1.0))
        u = (lon / (2 * np.pi) + 0.5) * width - 0.5
        v = (0.5 - lat / np.pi) * height - 0.5

        # bilinear, wrapping in longitude and clamping at the poles
        x0 = np.floor(u).astype(np.int32)
        y0 = np.clip(np.floor(v).astype(np.int32), 0, height - 2)
        fx = (u - x0)[..., None]
        fy = (v - y0)[..., None]
        x0 %= width
        x1 = (x0 + 1) % width
        y1 = y0 + 1
        top = source[y0, x0] * (1 - fx) + source[y0, x1] * fx
        bottom = source[y1, x0] * (1 - fx) + source[y1, x1] * fx
        out[name] = Image.fromarray(
            np.clip(top * (1 - fy) + bottom * fy, 0, 255).astype(np.uint8))
    return out


def paint(image: Image.Image) -> Image.Image:
    """Push a photographed sky towards the painted ones in the reference art.

    A tonemapped HDRI is honest and pale: the blue sits around 60% saturation
    and the cloud edges are soft, because that is what a camera records. The
    reference skies are the opposite -- a deep, almost cyan blue, clouds that
    are near-white with a readable edge, and no photographic mid-tone mush in
    between. Three moves get most of the way there and none of them invent
    detail: an S-curve on value, a strong saturation lift that leaves
    near-neutrals alone, and an unsharp mask on luminance only, so the cloud
    edges harden without the colours fringing.
    """
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0

    # value: S-curve about mid grey, so clouds go bright and sky goes deep
    rgb = np.clip(0.5 + (rgb - 0.5) * 1.34, 0.0, 1.0)

    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    # saturation, hue-preserving. Clouds are near-neutral and barely move.
    rgb = np.clip(lum[..., None] + (rgb - lum[..., None]) * 1.9, 0.0, 1.0)

    # and the blue itself: the reference sky is cooler than any real one, so
    # the sky half (which is everything that is not near-white) gets pushed
    sky = np.clip(1.0 - lum, 0.0, 1.0)[..., None]
    tint = np.array([0.90, 0.98, 1.10], dtype=np.float32)
    rgb = np.clip(rgb * (1.0 - sky) + rgb * tint * sky, 0.0, 1.0)

    # unsharp on luminance: hard cloud edges, no colour fringing
    blurred = np.asarray(
        Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
        .convert("L")
        .filter(ImageFilter.GaussianBlur(3.0)),
        dtype=np.float32,
    ) / 255.0
    lum2 = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    rgb = np.clip(rgb + (lum2 - blurred)[..., None] * 0.85, 0.0, 1.0)

    return Image.fromarray((rgb * 255).astype(np.uint8))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("slug")
    ap.add_argument("--cache", default="ph_sky")
    ap.add_argument("--out", default="ph_sky_faces")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--paint", action="store_true",
                    help="grade the faces towards painted rather than photographed")
    args = ap.parse_args()

    import json
    meta = os.path.join(args.cache, "_files", args.slug + ".json")
    fetch(f"{API}/files/{args.slug}", meta)
    url = json.load(open(meta))["tonemapped"]["url"]
    source = fetch(url, os.path.join(args.cache, args.slug + ".jpg"))

    Image.MAX_IMAGE_PIXELS = None
    equirect = Image.open(source)
    os.makedirs(args.out, exist_ok=True)
    for name, image in faces(equirect, args.size).items():
        path = os.path.join(args.out, f"sky_{name}.png")
        (paint(image) if args.paint else image).save(path)
        print(path)


if __name__ == "__main__":
    main()
