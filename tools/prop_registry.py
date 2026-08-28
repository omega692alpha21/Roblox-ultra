"""Emit the KINDS table in PropService from the Poly Haven upload log.

The map talks in roles ("Bin", "Chalkboard"); the asset store talks in Poly
Haven slugs and Roblox asset ids. This is where the two are married, so the
Luau file never carries a hand-typed id.
"""
import os, re, sys

# Where the downloaded FBX packs live. They are not in the repo (they are
# thirty megabytes of CC0 source art) but they are what the footprints are
# measured from, so the path is named here rather than guessed at.
SCRATCH = os.environ.get(
    "RBX_SCRATCH",
    "/tmp/claude-0/-home-user-Roblox-ultra/c9243cd0-6f22-5b01-98dd-c5d04d82a899/scratchpad",
)
FBX_DIRS = [os.path.join(SCRATCH, "q", "furniture"), os.path.join(SCRATCH, "q", "interior")]

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
    # Quaternius models are built at metre scale, so a chair imports about a
    # stud tall next to a five-stud student. Every one of them needs telling
    # how big a school thinks it is.
    "QuartersBed": 2.8,
    "QuartersBedDouble": 2.8,
    "QuartersCloset": 8.6,
    "QuartersLocker": 5.4,
    "QuartersNightstand": 2.8,
    "QuartersDesk": 3.6,
    "HeadmasterChair": 4.6,
    "TallBookcase": 8.6,
    "StockedBookcase": 8.6,
    "LodgeSofa": 3.6,
    "LodgeSofaLong": 3.6,
    "LodgeArmchair": 3.6,
    "LoungeStool": 2.8,
    "RefectoryTable": 3.4,
    "RefectoryTable2": 3.0,
    "PlainChair": 4.2,
    # Ultimate Home Interior, same metre scale
    "CeilingLampBox": 2.2,
    "CeilingLampDisc": 2.0,
    "PendantLamp": 3.4,
    "GrandChandelier": 5.4,
    "Houseplant": 5.4,
    "Houseplant2": 4.4,
    "Houseplant3": 6.2,
    "Houseplant4": 4.8,
    "BunkBed": 9.0,
    "Nightstand2": 2.8,
    "Fridge": 8.4,
    "Oven": 5.0,
    "KitchenSink": 5.0,
    "KitchenCabinet": 5.0,
    "KitchenDrawers": 5.0,
    "BinLarge": 4.6,
    "BinSmall": 2.8,
    "Toilet": 3.4,
    "Washbasin": 3.2,
    "WashroomMirror": 4.0,
    "WideShelf": 8.0,
    "DiningChair": 4.2,
    "RoundTable": 3.4,
    "RoundTableSmall": 2.8,
    "PaddedStool": 2.8,
    "LoungeCouch": 3.6,
    "ChestOfDrawers": 4.6,
    "Rug": 0.3,
    "RoundRug": 0.3,
    "LodgeFireplace": 8.0,
    # Kenney's kits are built at roughly a tenth of Roblox's scale -- a single
    # bed measures a stud and a bit end to end -- so every one of them is told
    # how tall a school thinks it is. Heights are the real-world figure: a bed
    # frame is knee high, a wardrobe is over your head.
    "BunkBed2": 9.0, "SingleBed": 2.6, "DoubleBed": 2.6,
    "BedsideDrawers": 2.6, "OpenBookcase": 7.0, "WideBookcase": 7.0,
    "BookStack": 1.2, "CoatRack": 7.0, "StudyDesk": 2.9, "StudyChair": 3.4,
    "SideDrawers": 2.8, "TableLamp": 2.0, "FloorLamp": 6.4,
    "CommonSofa": 3.0, "CommonChair": 3.0, "LowTable": 1.6,
    "LongPillow": 0.7, "RugRect": 0.2, "RugRound2": 0.2, "Bin2": 2.4,
    "DeskPlant": 1.6, "PottedPlant2": 4.2,
    "Basin2": 3.2, "Mirror2": 3.4, "Toilet2": 3.4, "Shower": 8.0,
    "LaundryStack": 6.6, "Stove2": 3.6, "Sink2": 3.6, "Fridge2": 7.0,
    "StoneWall": 14.0, "StoneWallCorner": 14.0, "StoneWallGate": 14.0,
    "StonePier": 16.0, "PicketFence": 6.0, "IronGate": 12.0,
    "StoneSteps": 5.0, "Banner": 12.0, "FallenLog": 2.6,
    "TowerBase": 16.0, "TowerMid": 16.0, "TowerTop": 20.0,
    "KTree": 26.0, "KTreeOak": 30.0, "KTreeTall": 34.0, "KTreeThin": 24.0,
    "KPineTall": 36.0, "KPineRound": 26.0, "KStump": 3.4,
    "KBush": 4.0, "KBushLarge": 6.0, "KGrass": 2.2,
    "KFlowerRed": 2.0, "KFlowerYellow": 2.0, "KFlowerPurple": 2.0,
    "KRockLarge": 7.0, "KRockTall": 12.0, "KRockSmall": 3.0,
    "KFencePlanks": 6.0, "KFenceGate": 7.0, "KCampfire": 2.0,
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


# Photoscanned consumer packaging is deliberately absent: its real printed
# label reads to Roblox moderation as an off-platform reference, and one of
# them cost the account a Directing Users Off-Platform strike. See
# tools/polyhaven.py BRANDED.
#
# The second wave. Where the first list was chosen role by role, this is a
# sweep: every school-plausible Poly Haven model under 15k triangles. Names are
# derived from the slug and the collide/shadow flags from the model's own size,
# because hand-writing 150 rows would only introduce mistakes. They are placed
# by scatter zones rather than one at a time (see MapService.furnishProps).
WAVE2 = [
    ("WoodenTable",               "wooden_table_02",                True, False),
    ("PaintedWoodenNightstand",   "painted_wooden_nightstand",      True, False),
    ("PaintedWoodenTable",        "painted_wooden_table",           True, True),
    ("ChineseSofa",               "chinese_sofa",                   True, True),
    ("ChineseStool",              "chinese_stool",                  True, False),
    ("RollershutterDoor",         "rollershutter_door",             True, True),
    ("RollershutterWindow",       "rollershutter_window_01",        True, True),
    ("RollershutterWindow2",      "rollershutter_window_02",        True, True),
    ("RollershutterWindow3",      "rollershutter_window_03",        True, True),
    ("Barrel",                    "barrel_03",                      True, True),
    ("StandingPictureFrame",      "standing_picture_frame_01",      False,False),
    ("Croissant",                 "croissant",                      False,False),
    ("SweetPotato",               "sweet_potato",                   False,False),
    ("CarvedWoodenPlate",         "carved_wooden_plate",            False,False),
    ("PaintedWoodenCabinet",      "painted_wooden_cabinet",         True, True),
    ("WoodenTable2",              "WoodenTable_03",                 True, True),
    ("Television2",               "television_02",                  False,False),
    ("ChineseTeaTable",           "chinese_tea_table",              False,False),
    ("BrassVase",                 "brass_vase_03",                  False,False),
    ("BaseballBat",               "baseball_bat",                   False,True),
    ("ChineseArmchair",           "chinese_armchair",               True, True),
    ("Barrel2",                   "Barrel_01",                      True, True),
    ("Barrel3",                   "Barrel_02",                      True, True),
    ("CarvedWoodenElephant",      "carved_wooden_elephant",         False,False),
    ("BrassVase2",                "brass_vase_04",                  False,False),
    ("CeramicVase",               "ceramic_vase_03",                False,False),
    ("OldTyre",                   "old_tyre",                       True, False),
    ("StandingPictureFrame2",     "standing_picture_frame_02",      False,False),
    ("WoodenDisplayShelves",      "wooden_display_shelves_01",      True, True),
    ("Plunger",                   "plunger",                        False,False),
    ("WoodenCandlestick",         "wooden_candlestick",             False,False),
    ("BrassPot",                  "brass_pot_02",                   False,False),
    ("SmallWoodenTable",          "small_wooden_table_01",          False,False),
    ("WoodenCuttingBoard",        "wooden_cutting_board",           False,False),
    ("CeramicPot",                "ceramic_pot",                    False,False),
    ("HangingPictureFrame",       "hanging_picture_frame_02",       False,False),
    ("BrassPot2",                 "brass_pot_01",                   False,False),
    ("GothicCommode",             "GothicCommode_01",               True, True),
    ("Lemon",                     "lemon",                          False,False),
    ("CoffeeTableRound",          "coffee_table_round_01",          False,False),
    ("PlasticContainer",          "plastic_container",              False,False),
    ("VintagePocketWatch",        "vintage_pocket_watch",           False,False),
    ("RoundWoodenTable",          "round_wooden_table_02",          True, False),
    ("BarberShopChair",           "BarberShopChair_01",             True, True),
    ("Dustpan",                   "dustpan",                        False,False),
    ("BrassPan",                  "brass_pan_01",                   False,False),
    ("PasticTorch6v",             "pastic_torch_6v",                False,False),
    ("VintageStapler",            "vintage_stapler",                False,False),
    ("Lightbulb",                 "lightbulb_01",                   False,False),
    ("UtilityBox",                "utility_box_01",                 True, True),
    ("Trashbag",                  "trashbag",                       False,False),
    ("WoodenBowl",                "wooden_bowl_02",                 False,False),
    ("CassettePlayer",            "cassette_player",                False,False),
    ("WoodenBucket",              "wooden_bucket_01",               False,False),
    ("WoodenCrate",               "wooden_crate_02",                False,False),
    ("YellowOnion",               "yellow_onion",                   False,False),
    ("GallineraTable",            "gallinera_table",                False,False),
    ("Jug",                       "jug_01",                         False,False),
    ("PaintedWoodenSofa",         "painted_wooden_sofa",            True, True),
    ("PlasticCrate",              "plastic_crate_02",               False,False),
    ("LanternChandelier",         "lantern_chandelier_01",          True, True),
    ("MetalJug",                  "metal_jug",                      False,False),
    ("WoodenLadder",              "wooden_ladder_02",               True, True),
    ("UtilityBox2",               "utility_box_02",                 True, True),
    ("FoldingWoodenStool",        "folding_wooden_stool",           False,False),
    ("WornMetalRack",             "worn_metal_rack",                True, True),
    ("SideTableTall",             "side_table_tall_01",             True, False),
    ("LightbulbLed",              "lightbulb_led",                  False,False),
    ("MetalStool",                "metal_stool_02",                 False,False),
    ("MetalStool2",               "metal_stool_03",                 True, True),
    ("WoodenCrate2",              "wooden_crate_01",                False,False),
    ("ChineseCommode",            "chinese_commode",                True, True),
    ("FoodLychee",                "food_lychee_01",                 False,False),
    ("GardenGloves",              "garden_gloves_01",               False,False),
    ("BrassVase3",                "brass_vase_02",                  False,False),
    ("FoodApple",                 "food_apple_01",                  False,False),
    ("IndustrialPasticContainer", "industrial_pastic_container",    False,False),
    ("FoodGinger",                "food_ginger_01",                 False,False),
    ("VintageOilLamp",            "vintage_oil_lamp",               False,False),
    ("WoodenBucket2",             "wooden_bucket_02",               False,False),
    ("SungkaBoard",               "sungka_board",                   False,False),
    ("BronzeSharkStatue",         "bronze_shark_statue",            False,False),
    ("ClassicConsole",            "ClassicConsole_01",              True, True),
    ("FoodAvocado",               "food_avocado_01",                False,False),
    ("FoodKiwi",                  "food_kiwi_01",                   False,False),
    ("ChineseChandelier",         "chinese_chandelier",             True, False),
    ("Sofa3",                     "sofa_03",                        True, True),
    ("ModernArmChair",            "modern_arm_chair_01",            True, True),
    ("SteelFrameShelves",         "steel_frame_shelves_03",         True, True),
    ("AlarmClock",                "alarm_clock_01",                 False,False),
    ("PlanterBox2",               "planter_box_02",                 False,False),
    ("PlanterBox3",               "planter_box_03",                 True, True),
    ("SeedingTray",               "seeding_tray_01",                False,False),
    ("WateringCanMetal",          "watering_can_metal_01",          False,False),
    ("GardenSprinkler",           "garden_sprinkler_01",            False,False),
    ("GardenHoseWallMounted",     "garden_hose_wall_mounted_01",    False,False),
    ("WoodenBroom",               "wooden_broom",                   True, True),
    ("MetalToolbox",              "metal_toolbox",                  False,False),
    ("MetalToolChest",            "metal_tool_chest",               True, False),
    ("HandTruck",                 "hand_truck",                     True, True),
    ("WoodenLadder2",             "wooden_ladder",                  True, True),
    ("OutdoorTableChairSet",      "outdoor_table_chair_set_01",     True, True),
    ("RoundWoodenTable2",         "round_wooden_table_01",          True, True),
    ("BarChairRound",             "bar_chair_round_01",             True, False),
    ("Rockingchair",              "Rockingchair_01",                True, True),
    ("GothicCabinet",             "GothicCabinet_01",               True, True),
    ("ChineseConsoleTable",       "chinese_console_table",          True, False),
    ("ModernCoffeeTable2",        "modern_coffee_table_02",         False,False),
    ("WoodenStool",               "wooden_stool_01",                False,False),
    ("WoodenStool2",              "wooden_stool_02",                False,False),
    ("MetalStool3",               "metal_stool_01",                 True, True),
    ("GallineraChair",            "gallinera_chair",                True, True),
    ("PotEnamel",                 "pot_enamel_01",                  False,False),
    ("HamburgerBuns",             "hamburger_buns",                 False,False),
    ("CarrotCake",                "carrot_cake",                    False,False),
    ("FoodPearsAsian",            "food_pears_asian_01",            False,False),
    ("FoodPomegranate",           "food_pomegranate_01",            False,False),
    ("FoodLime",                  "food_lime_01",                   False,False),
    ("SecurityCamera",            "security_camera_01",             False,False),
    ("SecurityCamera2",           "security_camera_02",             False,False),
    ("IndustrialWallSconce",      "industrial_wall_sconce",         False,False),
    ("IndustrialPipeLamp",        "industrial_pipe_lamp",           False,False),
    ("WoodenLantern",             "wooden_lantern_01",              False,False),
    ("BrassDiyaLantern",          "brass_diya_lantern",             False,False),
    ("BrassGoblets",              "brass_goblets",                  False,False),
    ("SeadogsCompass",            "seadogs_compass",                False,False),
    ("RoundSpectacles",           "round_spectacles",               False,False),
    ("FishermansHat",             "fishermans_hat",                 False,False),
    ("Lifebuoy",                  "lifebuoy",                       True, True),
    ("PortableCassettePlayer",    "portable_cassette_player",       False,False),
    ("RetroMultimeter",           "retro_multimeter",               False,False),
    ("VintageMicrowave",          "vintage_microwave",              False,False),
    ("VintageElectricKettle",     "vintage_electric_kettle",        False,False),
    ("Gamepad",                   "gamepad",                        False,False),
    ("DigitalWristWatch",         "digital_wrist_watch",            False,False),
    ("VintageFlashlight",         "vintage_flashlight",             False,False),
    ("SmallPlasticTorch",         "small_plastic_torch",            False,False),
    ("SignalFlashlight",          "signal_flashlight",              False,False),
    ("WineBarrel",                "wine_barrel_01",                 True, True),
]


# ---------------------------------------------------------------------------
# Quaternius, CC0 1.0 Universal (https://quaternius.com). Low-poly, flat-shaded
# and hand-made, where Poly Haven's are photoscans -- so these are used for the
# things a school needs that a scan library does not have: dormitory beds,
# closets, a headmaster's desk. Uploaded straight as FBX, which Roblox's
# importer takes without any repacking, so their "slug" is just the file stem.
QUATERNIUS = [
    ("QuartersBed",       "qt_BedTwin",         True,  True),
    ("QuartersBedDouble", "qt_BedDouble",       True,  True),
    ("QuartersCloset",    "qt_Closet",          True,  True),
    ("QuartersLocker",    "qt_ShortCloset",     True,  True),
    ("QuartersNightstand","qt_NightStand",      True,  True),
    ("QuartersDesk",      "qt_Desk",            True,  True),
    ("HeadmasterChair",   "qt_OfficeChair",     True,  True),
    ("TallBookcase",      "qt_Bookcase",        True,  True),
    ("StockedBookcase",   "qt_Bookcase_Books",  True,  True),
    ("LodgeSofa",         "qt_Sofa2",           True,  True),
    ("LodgeSofaLong",     "qt_Sofa3",           True,  True),
    ("LodgeArmchair",     "qt_Sofa_individual", True,  True),
    ("LoungeStool",       "qt_Stool",           True,  True),
    ("RefectoryTable",    "qt_Table",           True,  True),
    ("RefectoryTable2",   "qt_Table2",          True,  True),
    ("PlainChair",        "qt_Chair",           True,  True),
    # Ultimate Home Interior: fittings a school has and a scan library has not
    ("CeilingLampBox",    "qt_Light_Ceiling1",       False, False),
    ("CeilingLampDisc",   "qt_Light_Ceiling3",       False, False),
    ("PendantLamp",       "qt_Light_CeilingSingle",  False, False),
    ("GrandChandelier",   "qt_Light_Chandelier",     False, False),
    ("Houseplant",        "qt_Houseplant_1",         False, True),
    ("Houseplant2",       "qt_Houseplant_3",         False, True),
    ("Houseplant3",       "qt_Houseplant_5",         False, True),
    ("Houseplant4",       "qt_Houseplant_7",         False, True),
    ("BunkBed",           "qt_Bed_Bunk",             True,  True),
    ("Nightstand2",       "qt_NightStand_2",         True,  True),
    ("Fridge",            "qt_Kitchen_Fridge",       True,  True),
    ("Oven",              "qt_Kitchen_Oven_Large",   True,  True),
    ("KitchenSink",       "qt_Kitchen_Sink",         True,  True),
    ("KitchenCabinet",    "qt_Kitchen_Cabinet1",     True,  True),
    ("KitchenDrawers",    "qt_Kitchen_2Drawers",     True,  True),
    ("BinLarge",          "qt_Trashcan_Large",       True,  True),
    ("BinSmall",          "qt_Trashcan_Small1",      True,  True),
    ("Toilet",            "qt_Bathroom_Toilet",      True,  True),
    ("Washbasin",         "qt_Bathroom_Sink",        True,  True),
    ("WashroomMirror",    "qt_Bathroom_Mirror1",     False, False),
    ("WideShelf",         "qt_Shelf_Large",          True,  True),
    ("DiningChair",       "qt_Chair_3",              True,  True),
    ("RoundTable",        "qt_Table_RoundLarge",     True,  True),
    ("RoundTableSmall",   "qt_Table_RoundSmall",     True,  True),
    ("PaddedStool",       "qt_Stool",                True,  True),
    ("LoungeCouch",       "qt_Couch_Medium1",        True,  True),
    ("ChestOfDrawers",    "qt_Drawer_3",             True,  True),
    ("Rug",               "qt_Carpet_2",             False, False),
    ("RoundRug",          "qt_Carpet_Round",         False, False),
    ("LodgeFireplace",    "qt_Fireplace",            True,  True),
]

# ---------------------------------------------------------------------------
# Kenney.nl, CC0 1.0 Universal (https://kenney.nl). Flat-shaded, tiny, and
# consistent with each other -- which is exactly what the boarding houses and
# the staff lodge want, because a photoscanned bed next to a photoscanned
# wardrobe next to a hand-built brick wall reads as three different games.
#
# The furniture and castle kits upload as GLB. The nature kit's GLBs are
# rejected by the importer ("failed to parse") though they are well-formed;
# its FBX exports of the same models go through, so those are pulled as FBX
# and the slug carries no extension either way.
KENNEY = [
    # boarding house
    ("BunkBed2",        "kf-bedBunk",            True,  True),
    ("SingleBed",       "kf-bedSingle",          True,  True),
    ("DoubleBed",       "kf-bedDouble",          True,  True),
    ("BedsideDrawers",  "kf-cabinetBedDrawer",   True,  True),
    ("OpenBookcase",    "kf-bookcaseOpen",       True,  True),
    ("WideBookcase",    "kf-bookcaseClosedWide", True,  True),
    ("BookStack",       "kf-books",              False, False),
    ("CoatRack",        "kf-coatRackStanding",   True,  True),
    ("StudyDesk",       "kf-desk",               True,  True),
    ("StudyChair",      "kf-chairDesk",          True,  True),
    ("SideDrawers",     "kf-sideTableDrawers",   True,  True),
    ("TableLamp",       "kf-lampRoundTable",     False, False),
    ("FloorLamp",       "kf-lampSquareFloor",    False, True),
    ("CommonSofa",      "kf-loungeSofa",         True,  True),
    ("CommonChair",     "kf-loungeChair",        True,  True),
    ("LowTable",        "kf-tableCoffee",        True,  True),
    ("LongPillow",      "kf-pillowLong",         False, False),
    ("RugRect",         "kf-rugRectangle",       False, False),
    ("RugRound2",       "kf-rugRound",           False, False),
    ("Bin2",            "kf-trashcan",           True,  True),
    ("DeskPlant",       "kf-plantSmall1",        False, False),
    ("PottedPlant2",    "kf-pottedPlant",        False, True),
    # washroom and kitchen
    ("Basin2",          "kf-bathroomSink",       True,  True),
    ("Mirror2",         "kf-bathroomMirror",     False, False),
    ("Toilet2",         "kf-toilet",             True,  True),
    ("Shower",          "kf-shower",             True,  True),
    ("LaundryStack",    "kf-washerDryerStacked", True,  True),
    ("Stove2",          "kf-kitchenStove",       True,  True),
    ("Sink2",           "kf-kitchenSink",        True,  True),
    ("Fridge2",         "kf-kitchenFridge",      True,  True),
    # grounds and walling
    ("StoneWall",       "kc-wall",               True,  True),
    ("StoneWallCorner", "kc-wall-corner",        True,  True),
    ("StoneWallGate",   "kc-wall-doorway",       True,  True),
    ("StonePier",       "kc-wall-pillar",        True,  True),
    ("PicketFence",     "kc-wall-narrow-wood-fence", True, True),
    ("IronGate",        "kc-gate",               True,  True),
    ("StoneSteps",      "kc-stairs-stone",       True,  True),
    ("Banner",          "kc-flag-banner-long",   False, False),
    ("FallenLog",       "kc-tree-log",           True,  True),
    ("TowerBase",       "kc-tower-square-base",  True,  True),
    ("TowerMid",        "kc-tower-square-mid-windows", True, True),
    ("TowerTop",        "kc-tower-square-top-roof-high-windows", True, True),
    # nature, as FBX (see the note above)
    ("KTree",           "kn-tree_default",       True,  True),
    ("KTreeOak",        "kn-tree_oak",           True,  True),
    ("KTreeTall",       "kn-tree_tall",          True,  True),
    ("KTreeThin",       "kn-tree_thin",          True,  True),
    ("KPineTall",       "kn-tree_pineTallA",     True,  True),
    ("KPineRound",      "kn-tree_pineRoundA",    True,  True),
    ("KStump",          "kn-stump_old",          True,  True),
    ("KBush",           "kn-plant_bush",         False, True),
    ("KBushLarge",      "kn-plant_bushLarge",    False, True),
    ("KGrass",          "kn-grass_large",        False, False),
    ("KFlowerRed",      "kn-flower_redA",        False, False),
    ("KFlowerYellow",   "kn-flower_yellowA",     False, False),
    ("KFlowerPurple",   "kn-flower_purpleA",     False, False),
    ("KRockLarge",      "kn-rock_largeA",        True,  True),
    ("KRockTall",       "kn-rock_tallA",         True,  True),
    ("KRockSmall",      "kn-rock_smallA",        True,  True),
    ("KFencePlanks",    "kn-fence_planks",       True,  True),
    ("KFenceGate",      "kn-fence_gate",         True,  True),
    ("KCampfire",       "kn-campfire_logs",      False, True),
]

REGISTRY = REGISTRY + [(k, s, c, sh) for k, s, c, sh in WAVE2] + QUATERNIUS + KENNEY


def sizes(ids: dict, glb_dir: str, out_path: str) -> int:
    """Write the footprint of every available prop for MapService to scatter by.

    Scattering needs to know how much room a prop takes before it places it,
    and the only honest source for that is the mesh itself. This measures each
    packed .glb (after any height override) and writes a Luau table, so the
    game never carries a guessed size.
    """
    from prop_check import extent
    from fbx_extent import extent as fbx_extent

    lines = []
    for kind, slug, _collide, _shadow in REGISTRY:
        if slug not in ids:
            continue
        span = None
        path = os.path.join(glb_dir, slug + ".glb")
        if os.path.exists(path):
            lo, hi = extent(path)
            span = [hi[i] - lo[i] for i in range(3)]
        else:
            # An FBX prop. Roblox's importer takes those directly so nothing
            # repacked them and nothing measured them, which left fifty props
            # with no footprint -- and a prop with no footprint is a prop no
            # check can test. FBX is Z-up, so its Y and Z swap into Roblox's.
            for directory in FBX_DIRS:
                fbx = os.path.join(directory, slug[3:] + ".fbx")
                if os.path.exists(fbx):
                    lo, hi = fbx_extent(fbx)
                    raw = [hi[i] - lo[i] for i in range(3)]
                    span = [raw[0], raw[2], raw[1]]
                    break
        if span is None:
            continue
        if kind in HEIGHT and span[1] > 0.01:
            k = HEIGHT[kind] / span[1]
            span = [v * k for v in span]
        lines.append(f"\t{kind} = Vector3.new({span[0]:.2f}, {span[1]:.2f}, {span[2]:.2f}),")

    body = "\n".join(lines)
    with open(out_path, "w") as fh:
        fh.write(
            "--!strict\n"
            "-- Generated by tools/prop_registry.py -- do not edit by hand.\n"
            "--\n"
            "-- The size in studs of every prop the school can place, measured from the\n"
            "-- uploaded mesh. MapService scatters furniture into rooms and has to know\n"
            "-- how much floor each piece needs before it puts the next one down.\n"
            "-- Only kinds whose model actually uploaded appear here, so a scatter pool\n"
            "-- naturally narrows to what exists.\n"
            "return {\n" + body + "\n}\n"
        )
    return len(lines)


def main(ids_path: str, service_path: str, glb_dir: str = "", sizes_path: str = "") -> None:
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
        print(f"{len(missing)} not uploaded yet: " + ", ".join(missing[:8]) +
              (" ..." if len(missing) > 8 else ""))

    if glb_dir and sizes_path:
        print(f"measured {sizes(ids, glb_dir, sizes_path)} prop footprints")


if __name__ == "__main__":
    main(*sys.argv[1:])
