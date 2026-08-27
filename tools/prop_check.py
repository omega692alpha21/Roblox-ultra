"""Test furniture placements against the walls before anything is published.

A prop is placed from a coordinate typed into MapService, and a desk pushed
half a stud into a wall looks exactly as wrong as a desk pushed ten. This
reads the placements the harness dumped (tools/render_map.py) and the real
bounding box of each uploaded .glb, and reports every prop whose box overlaps
something solid.
"""
import json, os, struct, sys

REPO = sys.argv[1] if len(sys.argv) > 1 else "/home/user/Roblox-ultra"
EXPORT = sys.argv[2] if len(sys.argv) > 2 else "."
GLB = sys.argv[3] if len(sys.argv) > 3 else "ph_glb"


def glb_json(path):
    with open(path, "rb") as fh:
        fh.read(12)
        length, _kind = struct.unpack("<I4s", fh.read(8))
        return json.loads(fh.read(length))


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def trs(node):
    m = [[1 if i == j else 0 for j in range(4)] for i in range(4)]
    if "matrix" in node:
        c = node["matrix"]
        return [[c[j * 4 + i] for j in range(4)] for i in range(4)]
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        m = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0],
             [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0],
             [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0],
             [0, 0, 0, 1]]
    if "scale" in node:
        s = node["scale"]
        for i in range(3):
            for j in range(3):
                m[i][j] *= s[j]
    if "translation" in node:
        for i in range(3):
            m[i][3] = node["translation"][i]
    return m


def extent(path):
    """Local-space AABB of one packed .glb, in studs."""
    doc = glb_json(path)
    lo = [1e9] * 3
    hi = [-1e9] * 3

    def visit(index, parent):
        node = doc["nodes"][index]
        world = mul(parent, trs(node))
        if "mesh" in node:
            for prim in doc["meshes"][node["mesh"]].get("primitives", []):
                acc = doc["accessors"][prim["attributes"]["POSITION"]]
                if "min" not in acc:
                    continue
                for cx in (acc["min"][0], acc["max"][0]):
                    for cy in (acc["min"][1], acc["max"][1]):
                        for cz in (acc["min"][2], acc["max"][2]):
                            p = [world[i][0] * cx + world[i][1] * cy +
                                 world[i][2] * cz + world[i][3] for i in range(3)]
                            for i in range(3):
                                lo[i] = min(lo[i], p[i])
                                hi[i] = max(hi[i], p[i])
        for kid in node.get("children", []):
            visit(kid, world)

    ident = [[1 if i == j else 0 for j in range(4)] for i in range(4)]
    for root in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(root, ident)
    return lo, hi


def world_extent(size, position, rot):
    """Half-extents of a rotated box, projected onto the world axes."""
    return [sum(abs(rot[r * 3 + c]) * size[c] / 2 for c in range(3)) for r in range(3)]


def main():
    props = json.load(open(os.path.join(EXPORT, "_map_props.json")))
    parts = json.load(open(os.path.join(EXPORT, "_map_export.json")))

    registry, solid_kind = {}, {}
    sys.path.insert(0, os.path.join(REPO, "tools"))
    from prop_registry import REGISTRY, HEIGHT
    for kind, slug, collide, _shadow in REGISTRY:
        registry[kind] = slug
        solid_kind[kind] = collide

    boxes = {}
    for kind, slug in registry.items():
        path = os.path.join(GLB, slug + ".glb")
        if os.path.exists(path):
            boxes[kind] = extent(path)

    # only solid vertical structure can be clipped into; floors are meant to
    # be touched and a bin standing on one is not a fault
    solids = [p for p in parts if p.get("cc") and p["s"][1] >= 5 and p["t"] < 0.6]

    faults, placed = [], []
    for prop in props:
        box = boxes.get(prop["k"])
        if not box:
            print("no glb for kind", prop["k"])
            continue
        lo, hi = box
        scale = prop["sc"]
        if prop["k"] in HEIGHT and hi[1] - lo[1] > 0.01:
            scale *= HEIGHT[prop["k"]] / (hi[1] - lo[1])
        size = [(hi[i] - lo[i]) * scale for i in range(3)]
        # placement is by the base (or the top, when hung)
        cy = prop["p"][1] + (-size[1] / 2 if prop["hang"] else size[1] / 2)
        centre = [prop["p"][0], cy, prop["p"][2]]
        half = world_extent(size, centre, prop["r"])
        worst = None
        for part in solids:
            ph = world_extent(part["s"], part["p"], part["r"])
            gaps = [abs(centre[i] - part["p"][i]) - (half[i] + ph[i]) for i in range(3)]
            overlap = -max(gaps)
            if overlap > 0.4 and (worst is None or overlap > worst[0]):
                worst = (overlap, part["n"],
                         f'{part["n"]} at {[round(v, 1) for v in part["p"]]} '
                         f'size {[round(v, 1) for v in part["s"]]}')
        if worst:
            faults.append((round(worst[0], 1), prop["k"],
                           [round(v, 1) for v in prop["p"]], worst[2]))
        placed.append((prop, centre, half))

    faults.sort(reverse=True)
    print(f"{len(props)} props, {len(faults)} clipping into solid geometry")
    for f in faults[:40]:
        print(f"  {f[0]:6.1f} studs  {f[1]:18s} at {f[2]}  into {f[3]}")

    # furniture standing inside other furniture. Only solid pieces count --
    # a laptop is *meant* to be inside the volume of the desk it sits on.
    collisions = []
    solids_only = [t for t in placed if solid_kind.get(t[0]["k"])]
    for i, (a, ca, ha) in enumerate(solids_only):
        for b, cb, hb in solids_only[i + 1:]:
            gaps = [abs(ca[j] - cb[j]) - (ha[j] + hb[j]) for j in range(3)]
            overlap = -max(gaps)
            if overlap > 0.4:
                collisions.append((round(overlap, 1), a["k"], b["k"],
                                   [round(v, 1) for v in a["p"]]))
    collisions.sort(reverse=True)
    print(f"{len(collisions)} props standing inside each other")
    for c in collisions[:30]:
        print(f"  {c[0]:6.1f} studs  {c[1]:18s} / {c[2]:18s} near {c[3]}")
    return 1 if faults or collisions else 0


if __name__ == "__main__":
    sys.exit(main())
