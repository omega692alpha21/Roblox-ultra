#!/usr/bin/env python3
"""Hold every object in the game to one of two standards.

The complaint that started this was that things in the school are boxes
pretending to be objects -- a bench that is one slab, a lamp that is a cylinder
with a cube on top. The rule now is that a placeable thing is EITHER a scanned
CC0 mesh, downloaded and uploaded and recorded with its licence, OR a model
built here that clears a measured bar. Nothing in between.

The bar, checked against what the map actually emits:

  * every prop kind the map places resolves to an uploaded mesh in PropService
  * an assembly whose name says it is an object is not one bare part
  * an assembly is not all-identical parts (a stack of the same box is not a
    model, it is a stack of the same box)
  * an assembly is not mostly untextured plastic

    python3 tools/render_map.py . tools && python3 tools/asset_audit.py
"""
import json, os, re, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

# Names that promise an object rather than a piece of building fabric. A wall
# may be one slab; a bench may not.
OBJECT = (
    "Bench", "Lamp", "Lantern", "Fountain", "Statue", "Bin", "Desk", "Chair",
    "Table", "Locker", "Globe", "Clock", "Gate", "Post", "Bollard", "Planter",
    "Trophy", "Vending", "Piano", "Easel", "Telescope", "Microscope", "Cauldron",
)
# Fabric: walls, floors, roofs, trim. One part is a legitimate answer for these.
FABRIC = (
    "Wall", "Floor", "Slab", "Roof", "Ceiling", "Path", "Paving", "Kerb", "Curb",
    "Step", "Stair", "Tread", "Riser", "Beam", "Column", "Pier", "Sill", "Cap",
    "Course", "Quoin", "Coping", "Ridge", "Eaves", "Gable", "Panel", "Pane",
    "Glass", "Window", "Door", "Frame", "Trim", "Band", "Plinth", "Verge",
    "Turf", "Grass", "Soil", "Hedge", "Water", "Leaf", "Sign", "Board", "Plaque",
    "Crest", "Banner", "Line", "Marking", "Rail", "Fence", "Tarmac", "Bay",
    "Apron", "Verandah", "Terrace", "Joint", "Border",
)
PLASTIC = ("Plastic", "SmoothPlastic")


def kinds_with_meshes():
    src = open(os.path.join(REPO, "src/ServerScriptService/Services/PropService.luau")).read()
    m = re.search(r"local KINDS: \{ \[string\]: Spec \} = \{(.*?)\n\}", src, re.S)
    return set(re.findall(r"^\t(\w+)\s*=\s*\{ id =", m.group(1), re.M)) if m else set()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    parts = json.load(open(os.path.join(out, "_map_export.json")))
    props = json.load(open(os.path.join(out, "_map_props.json")))
    bad = []

    # ---- 1. every placed prop kind is a real uploaded mesh ------------------
    have = kinds_with_meshes()
    placed = sorted({p["k"] for p in props})
    for kind in placed:
        if kind not in have:
            bad.append(("placeholder", f"{kind} is placed {sum(1 for p in props if p['k'] == kind)} "
                                       f"times and has no mesh behind it"))

    # ---- 2. built assemblies clear the detail bar ---------------------------
    # The map is FLAT -- almost every part is parented straight to the folder --
    # so grouping by parent counts four separate lamp posts as one lamp made of
    # four identical posts. Objects have to be recovered instead: take the name
    # up to and including the word that says what it is ("WalkLampPost" ->
    # "WalkLamp", "StatueTorso" -> "Statue"), then cluster those parts by
    # position, because two lamps thirty studs apart are two lamps.
    def stem(name):
        for word in OBJECT:
            i = name.find(word)
            if i >= 0 and not any(w in name for w in FABRIC):
                return name[: i + len(word)]
        return None

    by_stem = defaultdict(list)
    for p in parts:
        key = stem(p["n"])
        if key:
            by_stem[key].append(p)

    LINK = 6.0  # two parts with less than this much air between them are one object

    def half_extents(p):
        r, s_ = p["r"], p["s"]
        return [0.5 * sum(abs(r[i * 3 + j]) * s_[j] for j in range(3)) for i in range(3)]

    def gap(a, b):
        """The air between two parts' boxes, not the distance between centres.

        Centre-to-centre put the jambs of a 62-stud homeroom gate thirty studs
        from its head -- so a gate that IS a frame with a field in it came back
        as three loose parts. What decides whether two parts are one object is
        whether they touch.
        """
        ha, hb = half_extents(a), half_extents(b)
        total = 0.0
        for i in range(3):
            d = abs(a["p"][i] - b["p"][i]) - ha[i] - hb[i]
            if d > 0:
                total += d * d
        return total ** 0.5

    def cluster(members):
        remaining = list(members)
        out = []
        while remaining:
            seed = remaining.pop()
            group, queue = [seed], [seed]
            while queue:
                a = queue.pop()
                near = [b for b in remaining if gap(a, b) < LINK]
                for b in near:
                    remaining.remove(b)
                    group.append(b)
                    queue.append(b)
            out.append(group)
        return out

    MIN_PARTS = 6
    # A cluster sitting on top of a mesh prop is that prop: a scanned lamp post
    # shows up in the parts dump only as the little neon lens that carries its
    # PointLight, and calling that a one-part lamp is exactly backwards.
    MESH_NEAR = 16.0
    prop_at = [(p["p"][0], p["p"][2]) for p in props]

    def mesh_backed(group):
        for m in group:
            for px, pz in prop_at:
                if (m["p"][0] - px) ** 2 + (m["p"][2] - pz) ** 2 < MESH_NEAR * MESH_NEAR:
                    return True
        return False

    # A cluster standing INSIDE a larger assembly is a component of it, not an
    # object of its own.
    #
    # This groups parts by what their name says they are, so the six lamp units
    # in a floodlight head come back as "one FloodLamp made of six identical
    # boxes" -- which is exactly what a floodlight head is, and the mast under
    # them is twenty-five parts the check never sees because none of them is
    # called a lamp. Same for the four posts of the bus shelter and the lantern
    # hanging in it. So: look at everything standing around the cluster, ignore
    # building fabric (a locker against a wall is still a locker on its own),
    # and if what is left is an assembly in its own right, the cluster is part
    # of it.
    ASSEMBLY_NEAR = 8.0

    def component_of_assembly(group):
        # everything standing here that is not this cluster's own parts. The
        # first version of this looked only at parts with no object name of
        # their own, so a bus shelter's four posts could not see its benches,
        # its fascia or its lantern -- all of which are named as objects -- and
        # the shelter read as four bare posts standing in a field.
        own = {m["n"] for m in group}
        seen_names = set()
        count = 0
        for q in parts:
            if q["n"] in own or any(w in q["n"] for w in FABRIC):
                continue
            for m in group:
                if gap(m, q) < ASSEMBLY_NEAR:
                    seen_names.add(q["n"])
                    count += 1
                    break
        return count >= MIN_PARTS and len(seen_names) >= 3

    thin, uniform, plasticky = [], [], []
    objects = 0
    for key, members in by_stem.items():
        for group in cluster(members):
            objects += 1
            if len(group) < MIN_PARTS and (mesh_backed(group) or component_of_assembly(group)):
                continue
            if len(group) < MIN_PARTS:
                thin.append((key, len(group), [round(v) for v in group[0]["p"]]))
                continue
            sizes = {tuple(round(v, 2) for v in m["s"]) for m in group}
            colours = {tuple(m["c"]) for m in group}
            if len(sizes) == 1 and len(colours) == 1 and not component_of_assembly(group):
                uniform.append((key, len(group)))
            # Bare plastic is only evidence of a placeholder when the thing has
            # no shape to it either. A lacquered piano is 44 differently sized
            # pieces and correctly smooth: flagging it would be flagging the
            # material a piano is actually made of.
            share = sum(1 for m in group if m["m"] in PLASTIC) / len(group)
            if share > 0.85 and len(sizes) < 4:
                plasticky.append((key, round(share * 100), len(group)))

    counts = defaultdict(int)
    for key, n, at in thin:
        counts[key] += 1
    for key in sorted(counts, key=lambda k: -counts[k])[:14]:
        example = next(t for t in thin if t[0] == key)
        bad.append(("thin", f"{key}: {counts[key]} of them, {example[1]} parts each "
                            f"(e.g. at {example[2]}); an object wants {MIN_PARTS}"))
    for key, n in uniform[:8]:
        bad.append(("uniform", f"{key} is {n} copies of one box in one colour"))
    for key, pct, n in plasticky[:8]:
        bad.append(("untextured", f"{key} is {pct}% bare plastic across {n} parts"))

    print(f"{len(placed)} prop kinds placed, {len(placed) - sum(1 for k in placed if k not in have)}"
          f" backed by CC0 meshes; {objects} built objects recovered from {len(by_stem)} kinds")
    if not bad:
        print("every object is a scanned mesh or clears the bar.")
        return 0
    for where, why in bad:
        print(f"  [{where}] {why}")
    print(f"{len(bad)} objects below the bar")
    return 1


if __name__ == "__main__":
    sys.exit(main())
