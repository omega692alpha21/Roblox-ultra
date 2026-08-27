"""Turn Poly Haven's CC0 PBR texture sets into Roblox MaterialVariant maps.

The school's surfaces were hand-painted procedurally (tools/paint_textures.py):
value noise, baked occlusion, a bit of grime. That got the surfaces off flat
colour, but it is still noise pretending to be brick. These are photographed
and scanned materials, and the difference at a glance is total.

Three things have to happen on the way in:

  * Roblox's MaterialVariant has ColorMap, NormalMap, RoughnessMap and
    MetalnessMap -- and no ambient-occlusion slot. Poly Haven ships AO
    separately, so it is multiplied into the colour map here. That contact
    shading in the mortar joints is most of why a real brick wall reads as
    brick and a tiled photo does not.
  * The maps go in as 1024 square. Roblox resamples anything larger anyway and
    a 4K map costs memory on a phone, which is the device this game is played
    on.
  * Roughness has to be a single channel; Poly Haven's rough map is already
    greyscale but is stored as RGB JPEG.
"""
import argparse, json, os, subprocess, sys

from PIL import Image, ImageChops

API = "https://api.polyhaven.com"
SIZE = 1024


def fetch(url: str, dest: str) -> str:
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return dest
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    subprocess.run(["curl", "-sS", "-L", "--max-time", "180", "-o", dest, url], check=True)
    return dest


def manifest(slug: str, cache: str) -> dict:
    path = os.path.join(cache, "_files", slug + ".json")
    fetch(f"{API}/files/{slug}", path)
    return json.load(open(path))


def grab(files: dict, kind: str, slug: str, cache: str, resolution: str):
    entry = files.get(kind, {}).get(resolution, {}).get("jpg")
    if not entry:
        return None
    dest = os.path.join(cache, slug, f"{kind}.jpg")
    fetch(entry["url"], dest)
    return Image.open(dest)


def build(slug: str, name: str, cache: str, out: str, resolution: str = "1k",
          gain: float = 1.0) -> dict:
    files = manifest(slug, cache)
    colour = grab(files, "Diffuse", slug, cache, resolution)
    if colour is None:
        raise SystemExit(f"{slug}: no diffuse map")
    colour = colour.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)

    occlusion = grab(files, "AO", slug, cache, resolution)
    if occlusion is not None:
        occlusion = occlusion.convert("L").resize((SIZE, SIZE), Image.LANCZOS)
        # straight multiply: AO belongs in the albedo when there is nowhere
        # else for it to go
        colour = Image.merge("RGB", [ImageChops.multiply(c, occlusion)
                                     for c in colour.split()])

    if gain != 1.0:
        # MaterialVariant modulates the colour map by BasePart.Color, which can
        # only darken. A map that is too dark for its job has to be lifted
        # here or it stays too dark in game.
        colour = Image.merge("RGB", [c.point(lambda v: min(255, int(v * gain)))
                                     for c in colour.split()])

    os.makedirs(out, exist_ok=True)
    written = {}
    colour_path = os.path.join(out, f"{name}_color.png")
    colour.save(colour_path)
    written["ColorMap"] = colour_path

    normal = grab(files, "nor_gl", slug, cache, resolution)
    if normal is not None:
        path = os.path.join(out, f"{name}_normal.png")
        normal.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(path)
        written["NormalMap"] = path

    rough = grab(files, "Rough", slug, cache, resolution)
    if rough is not None:
        path = os.path.join(out, f"{name}_rough.png")
        rough.convert("L").resize((SIZE, SIZE), Image.LANCZOS).save(path)
        written["RoughnessMap"] = path

    metal = grab(files, "Metal", slug, cache, resolution)
    if metal is not None:
        path = os.path.join(out, f"{name}_metal.png")
        metal.convert("L").resize((SIZE, SIZE), Image.LANCZOS).save(path)
        written["MetalnessMap"] = path

    return written


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("pairs", nargs="+", help="Name=polyhaven_slug[@gain]")
    ap.add_argument("--cache", default="ph_tex")
    ap.add_argument("--out", default="ph_maps")
    ap.add_argument("--resolution", default="1k")
    args = ap.parse_args()
    for pair in args.pairs:
        name, slug = pair.split("=", 1)
        gain = 1.0
        if "@" in slug:
            slug, raw = slug.split("@", 1)
            gain = float(raw)
        written = build(slug, name, args.cache, args.out, args.resolution, gain)
        print(name, slug, " ".join(sorted(written)))


if __name__ == "__main__":
    main()
