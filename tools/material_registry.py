"""Point the MaterialVariants at the uploaded Poly Haven maps.

StudsPerTile is not a look-and-see number: Poly Haven records the real-world
size each texture was shot at, and the school is built at 3.7 studs to the
metre, so the tile size follows from the source rather than from taste. A
3 m brick sheet is 11 studs across and the courses land at the height a
person would expect them to.

The variants themselves are Rojo .model.json data rather than script output,
because MaterialVariant.ColorMap and friends are plugin-security properties: a
script can never assign them, but Rojo serialises them into the place file.
"""
import json, os, sys

STUDS_PER_METRE = 3.7

# name -> (BaseMaterial, poly haven slug, real-world tile size in metres)
MATERIALS = [
    ("SchoolBrick",   "Brick",        "brick_wall_001",    3.0),
    ("SchoolPlaster", "Plaster",      "plastered_wall_02", 2.23),
    ("SchoolStone",   "Slate",        "marble_01",         1.5),
    ("SchoolWood",    "WoodPlanks",   "wood_floor",        1.7),
    ("SchoolTile",    "CeramicTiles", "floor_tiles_02",    4.0),
    ("SchoolCeiling", "Concrete",     "ceiling_interior",  2.0),
    ("SchoolLocker",  "Metal",        "blue_metal_plate",  2.5),
    ("SchoolShingle", "Cobblestone",  "roof_slates_02",    3.0),
    ("SchoolLawn",    "Grass",        "leafy_grass",       2.0),
]

SLOTS = [("ColorMap", "color"), ("NormalMap", "normal"),
         ("RoughnessMap", "rough"), ("MetalnessMap", "metal")]


def main(ids_path: str, variant_dir: str) -> None:
    ids = {}
    for line in open(ids_path):
        if "=" in line:
            key, value = line.strip().split("=", 1)
            if value.isdigit():
                ids[key] = value

    for name, base, _slug, metres in MATERIALS:
        maps = {}
        for prop, suffix in SLOTS:
            asset = ids.get(f"{name}_{suffix}")
            if asset:
                maps[prop] = f"rbxassetid://{asset}"
        if "ColorMap" not in maps:
            print(f"{name}: no colour map uploaded, left alone")
            continue
        payload = {
            "className": "MaterialVariant",
            "properties": dict(
                BaseMaterial=base,
                StudsPerTile=round(metres * STUDS_PER_METRE),
                **maps,
            ),
        }
        path = os.path.join(variant_dir, name + ".model.json")
        with open(path, "w") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
        print(f"{name}: {len(maps)} maps, {payload['properties']['StudsPerTile']} studs/tile")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
