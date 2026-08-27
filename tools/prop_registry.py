"""Emit the KINDS table in PropService from the Poly Haven upload log.

The map talks in roles ("Bin", "Chalkboard"); the asset store talks in Poly
Haven slugs and Roblox asset ids. This is where the two are married, so the
Luau file never carries a hand-typed id.
"""
import re, sys

# Height in studs, where the source model's own scale is not what the school
# needs. Poly Haven's "steel_frame_shelves_01" is a 21 m warehouse rack and its
# "WoodenTable_02" is 40 cm tall; both are correct and neither is a classroom.
HEIGHT = {
    "SteelShelves": 7.6,
    "Table2": 2.6,
    "Shrub": 2.4,
    "Flowers": 2.2,
    "PottedPlant": 5.0,
    "PlanterPot": 3.0,
    "PlanterBox": 3.0,
    "Mirror": 6.0,
    "FramedPicture": 3.0,
    "Television": 3.0,
    "BunsenBurner": 1.6,
    "Baseball": 0.6,
    "Fern": 2.4,
}

# kind -> (poly haven slug, collides with players, casts a shadow)
REGISTRY = [
    ("SchoolDesk",        "SchoolDesk_01",                 True,  True),
    ("SchoolChair",       "SchoolChair_01",                True,  True),
    ("OfficeDesk",        "metal_office_desk",             True,  True),
    ("Chalkboard",        "standing_chalkboard_01",        True,  True),
    ("ProjectorScreen",   "projector_screen",              True,  True),
    ("Bookshelf",         "wooden_bookshelf_worn",         True,  True),
    ("Shelf",             "Shelf_01",                      True,  False),
    ("SteelShelves",      "steel_frame_shelves_01",        True,  True),
    ("SteelShelves2",     "steel_frame_shelves_02",        True,  True),
    ("Clock",             "wall_clock",                    False, False),
    ("Laptop",            "classic_laptop",                False, False),
    ("Stationery",        "stationery_supplies",           False, False),
    ("Notepads",          "office_notepads",               False, False),
    ("Clipboard",         "clipboard",                     False, False),
    ("BunsenBurner",      "bunsen_burner",                 False, False),
    ("FireAlarm",         "fire_alarm",                    False, False),
    ("Extinguisher",      "korean_fire_extinguisher_01",   False, False),
    ("Bin",               "metal_trash_can",               True,  True),
    ("WetFloorSign",      "WetFloorSign_01",               False, False),
    ("Table",             "WoodenTable_01",                True,  True),
    ("Table2",            "WoodenTable_02",                True,  True),
    ("Chair",             "painted_wooden_chair_01",       True,  True),
    ("Chair2",            "painted_wooden_chair_02",       True,  True),
    ("ArmChair",          "ArmChair_01",                   True,  True),
    ("Sofa",              "Sofa_01",                       True,  True),
    ("Sofa2",             "sofa_02",                       True,  True),
    ("CoffeeTable",       "CoffeeTable_01",                True,  True),
    ("SideTable",         "side_table_01",                 True,  False),
    ("CeilingLamp",       "modern_ceiling_lamp_01",        False, False),
    ("HangingLamp",       "hanging_industrial_lamp",       False, False),
    ("PictureFrame",      "hanging_picture_frame_01",      False, False),
    ("FramedPicture",     "fancy_picture_frame_01",        False, False),
    ("Mirror",            "ornate_mirror_01",              False, False),
    ("WhaleStatue",       "bronze_whale_statue",           True,  True),
    ("RayStatue",         "bronze_ray_statue",             True,  True),
    ("Vase1",             "ceramic_vase_01",               False, False),
    ("Vase2",             "ceramic_vase_02",               False, False),
    ("Vase4",             "ceramic_vase_04",               False, False),
    ("PlanterPot",        "planter_pot_clay",              True,  True),
    ("PlanterBox",        "planter_box_01",                True,  True),
    ("PottedPlant",       "potted_plant_04",               True,  True),
    ("Fern",              "fern_02",                       False, False),
    ("GrandfatherClock",  "vintage_grandfather_clock_01",  True,  True),
    ("Ottoman",           "Ottoman_01",                    True,  False),
    ("GreenChair",        "GreenChair_01",                 True,  True),
    ("MonoblocChair",     "plastic_monobloc_chair_01",     True,  True),
    ("DiningTable",       "dining_table",                  True,  True),
    ("Bench",             "painted_wooden_bench",          True,  True),
    ("Stool",             "painted_wooden_stool",          True,  False),
    ("PicnicTable",       "wooden_picnic_table",           True,  True),
    ("Football",          "football",                      False, False),
    ("AmericanFootball",  "american_football",             False, False),
    ("Baseball",          "baseball_01",                   False, False),
    ("Dartboard",         "dartboard",                     False, False),
    ("Shrub",             "shrub_sorrel_01",               False, False),
    ("Flowers",           "flower_empodium",               False, False),
    ("SecurityLight",     "security_light",                False, False),
    ("IndustrialLamp",    "industrial_wall_lamp",          False, False),
    ("DayBed",            "vintage_day_bed",               True,  True),
    ("Nightstand",        "ClassicNightstand_01",          True,  False),
    ("Cabinet",           "painted_wooden_cabinet_02",     True,  True),
    ("Drawer",            "vintage_wooden_drawer_01",      True,  True),
    ("Pillows",           "throw_pillows_01",              False, False),
    ("Boombox",           "boombox",                       False, False),
    ("Television",        "Television_01",                 False, False),
    ("LoungeChair",       "mid_century_lounge_chair",      True,  True),
    ("ModernCoffeeTable", "modern_coffee_table_01",        True,  True),
]


def main(ids_path: str, service_path: str) -> None:
    ids = {}
    for line in open(ids_path):
        if "=" in line:
            slug, value = line.strip().split("=", 1)
            if value.isdigit():
                ids[slug] = int(value)

    lines, missing = [], []
    width = max(len(k) for k, *_ in REGISTRY)
    for kind, slug, collide, shadow in REGISTRY:
        if slug not in ids:
            missing.append(f"{kind} ({slug})")
            continue
        flags = ""
        if collide:
            flags += ", collide = true"
        if shadow:
            flags += ", shadow = true"
        if kind in HEIGHT:
            flags += f", height = {HEIGHT[kind]}"
        lines.append(f"\t{kind.ljust(width)} = {{ id = {ids[slug]}{flags} }}, -- {slug}")

    body = "\n".join(lines)
    src = open(service_path).read()
    src = re.sub(r"local KINDS: \{ \[string\]: Spec \} = \{\n.*?\n\}\n",
                 "local KINDS: { [string]: Spec } = {\n" + body + "\n}\n",
                 src, count=1, flags=re.S)
    open(service_path, "w").write(src)
    print(f"wrote {len(lines)} prop kinds")
    if missing:
        print("MISSING:", ", ".join(missing))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
