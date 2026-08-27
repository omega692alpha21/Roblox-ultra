"""Pull CC0 models from Poly Haven and repack them as self-contained .glb.

Poly Haven ships glTF as a .gltf + .bin + loose JPEGs. Roblox's Open Cloud
asset endpoint takes exactly one file, so everything has to travel inside a
single binary glTF: the .bin becomes the BIN chunk and every image is folded
in as a bufferView. That is also the only way a texture survives the trip --
MeshPart.TextureID cannot be assigned from a script, so the material has to
arrive with the mesh.

Poly Haven authors in metres. The school is built at roughly 3.7 studs to the
metre (a 0.75 m classroom desk stands 2.8 studs tall), so positions are scaled
on the way through rather than left for a runtime resize.
"""
import argparse, hashlib, json, os, struct, subprocess, sys

API = "https://api.polyhaven.com"
STUDS_PER_METRE = 3.7

# glTF componentType -> (struct code, bytes)
COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
             5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
         "MAT2": 4, "MAT3": 9, "MAT4": 16}


def fetch(url: str, dest: str) -> str:
    """curl, because the sandbox's egress proxy rejects urllib."""
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return dest
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    subprocess.run(["curl", "-sS", "-L", "--max-time", "180", "-o", dest, url],
                   check=True)
    return dest


def manifest(slug: str, cache: str) -> dict:
    path = os.path.join(cache, "_files", slug + ".json")
    fetch(f"{API}/files/{slug}", path)
    return json.load(open(path))


def download(slug: str, cache: str, resolution: str = "1k") -> str:
    """Fetch the gltf bundle for one asset; return the .gltf path."""
    files = manifest(slug, cache)["gltf"][resolution]["gltf"]
    root = os.path.join(cache, slug)
    gltf = os.path.join(root, os.path.basename(files["url"]))
    fetch(files["url"], gltf)
    for rel, spec in files.get("include", {}).items():
        fetch(spec["url"], os.path.join(root, rel))
    return gltf


def scale_nodes(doc: dict, factor: float) -> None:
    """Scale the node hierarchy's translations to match the scaled geometry.

    Missing this is subtle and ugly: the four fronds of a fern are one mesh
    placed at four offsets, so scaling only the vertex data grows each frond
    but leaves the offsets in metres -- the fern arrives as a clump.
    """
    for node in doc.get("nodes", []):
        if "translation" in node:
            node["translation"] = [v * factor for v in node["translation"]]
        if "matrix" in node:
            m = list(node["matrix"])  # column-major; translation is the last column
            for i in range(12, 15):
                m[i] *= factor
            node["matrix"] = m


def scale_positions(doc: dict, blob: bytearray, factor: float) -> None:
    """Multiply every POSITION accessor by `factor`, in place."""
    position_accessors = set()
    for mesh in doc.get("meshes", []):
        for prim in mesh.get("primitives", []):
            idx = prim.get("attributes", {}).get("POSITION")
            if idx is not None:
                position_accessors.add(idx)
    for idx in position_accessors:
        acc = doc["accessors"][idx]
        if "bufferView" not in acc:
            continue
        code, width = COMPONENT[acc["componentType"]]
        if code != "f":
            raise SystemExit(f"POSITION accessor {idx} is not float")
        view = doc["bufferViews"][acc["bufferView"]]
        base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        n = NCOMP[acc["type"]]
        stride = view.get("byteStride") or n * width
        for i in range(acc["count"]):
            off = base + i * stride
            vals = struct.unpack_from("<3f", blob, off)
            struct.pack_into("<3f", blob, off, *(v * factor for v in vals))
        for key in ("min", "max"):
            if key in acc:
                acc[key] = [v * factor for v in acc[key]]


def pack(gltf_path: str, out_path: str, factor: float = STUDS_PER_METRE,
         drop_maps: bool = False) -> str:
    """Fold the .bin and every image into one .glb."""
    root = os.path.dirname(gltf_path)
    doc = json.load(open(gltf_path))
    if len(doc.get("buffers", [])) != 1:
        raise SystemExit(f"{gltf_path}: expected exactly one buffer")
    blob = bytearray(open(os.path.join(root, doc["buffers"][0]["uri"]), "rb").read())
    scale_positions(doc, blob, factor)
    scale_nodes(doc, factor)

    def append(payload: bytes) -> int:
        while len(blob) % 4:
            blob.append(0)
        offset = len(blob)
        blob.extend(payload)
        doc["bufferViews"].append({"buffer": 0, "byteOffset": offset,
                                   "byteLength": len(payload)})
        return len(doc["bufferViews"]) - 1

    for image in doc.get("images", []):
        uri = image.pop("uri", None)
        if uri is None:
            continue
        data = open(os.path.join(root, uri), "rb").read()
        image["bufferView"] = append(data)
        image.setdefault("mimeType",
                         "image/png" if uri.endswith(".png") else "image/jpeg")

    if drop_maps:
        # Some props read better flat-shaded than with a tangent-space normal
        # map baked for a renderer we do not control.
        for mat in doc.get("materials", []):
            mat.pop("normalTexture", None)
            mat.pop("occlusionTexture", None)

    doc["buffers"][0] = {"byteLength": len(blob)}
    doc["buffers"][0].pop("uri", None)

    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(blob) % 4:
        blob.append(0)
    body = (struct.pack("<I", len(js)) + b"JSON" + js +
            struct.pack("<I", len(blob)) + b"BIN\x00" + bytes(blob))
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "wb") as fh:
        fh.write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)
    return out_path


def triangles(gltf_path: str) -> int:
    doc = json.load(open(gltf_path))
    total = 0
    for mesh in doc.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "indices" in prim:
                total += doc["accessors"][prim["indices"]]["count"] // 3
    return total


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("slugs", nargs="+")
    ap.add_argument("--cache", default="ph")
    ap.add_argument("--out", default="ph_glb")
    ap.add_argument("--resolution", default="1k")
    ap.add_argument("--scale", type=float, default=STUDS_PER_METRE)
    args = ap.parse_args()
    for slug in args.slugs:
        gltf = download(slug, args.cache, args.resolution)
        out = pack(gltf, os.path.join(args.out, slug + ".glb"), args.scale)
        print(f"{slug}\t{triangles(gltf)} tris\t{os.path.getsize(out)} bytes")


if __name__ == "__main__":
    main()
