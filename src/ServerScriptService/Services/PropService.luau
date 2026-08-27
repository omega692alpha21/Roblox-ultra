--!strict
-- Real furniture.
--
-- Everything in the school used to be a box: a desk was a slab on four thin
-- prisms, a bin was a cylinder, a plant was a green cone. No amount of texture
-- work fixes that, because the silhouette is what you read first. These are
-- scanned/modelled props from Poly Haven -- CC0, so they can be repacked and
-- uploaded to this account (tools/polyhaven.py) rather than merely admired.
--
-- Same constraint that shaped TrimService: MeshPart.MeshId cannot be assigned
-- from a script. A template loaded through InsertService carries its MeshId
-- (and the textures baked into the .glb) as data, and a clone of it keeps
-- both. So MapService records where each prop goes and this places them.
--
-- Where a prop stands in for block furniture that already exists, MapService
-- hands over the placeholder in `fallback`. It is destroyed only after the
-- model has actually loaded, so an asset outage leaves a furnished classroom
-- rather than an empty one.

local InsertService = game:GetService("InsertService")

local MapService = require(script.Parent.MapService)

local PropService = {}

type Spec = {
	id: number,
	collide: boolean?, -- furniture you can bump into; small dressing is not
	shadow: boolean?, -- off by default for anything hand-sized
	-- Poly Haven authors at real-world scale, but "real-world" varies: one
	-- shelving unit is a two-storey warehouse rack, one table is a doll's
	-- table. `height` pins a prop to a size in studs and the model is scaled
	-- to match, so the school stays in proportion whatever the source assumed.
	height: number?,
}

local KINDS: { [string]: Spec } = {
	SchoolDesk                = { id = 126069129781784, collide = true, shadow = true }, -- SchoolDesk_01
	SchoolChair               = { id = 86158548904779, collide = true, shadow = true }, -- SchoolChair_01
	OfficeDesk                = { id = 117814615626586, collide = true, shadow = true }, -- metal_office_desk
	Chalkboard                = { id = 139944048015518, collide = true, shadow = true }, -- standing_chalkboard_01
	ProjectorScreen           = { id = 131655294209917, collide = true, shadow = true }, -- projector_screen
	Bookshelf                 = { id = 111602596532178, collide = true, shadow = true }, -- wooden_bookshelf_worn
	Shelf                     = { id = 137144936926067, collide = true }, -- Shelf_01
	SteelShelves              = { id = 91674694775035, collide = true, shadow = true, height = 7.6 }, -- steel_frame_shelves_01
	SteelShelves2             = { id = 99718506671397, collide = true, shadow = true }, -- steel_frame_shelves_02
	Clock                     = { id = 106161527319573 }, -- wall_clock
	Laptop                    = { id = 96677810707224 }, -- classic_laptop
	Stationery                = { id = 100753846020322 }, -- stationery_supplies
	Notepads                  = { id = 105565813304178 }, -- office_notepads
	Clipboard                 = { id = 90168931687194 }, -- clipboard
	BunsenBurner              = { id = 81032639006463, height = 1.6 }, -- bunsen_burner
	FireAlarm                 = { id = 98131827261163 }, -- fire_alarm
	Extinguisher              = { id = 131695449907539 }, -- korean_fire_extinguisher_01
	Bin                       = { id = 126919211473706, collide = true, shadow = true }, -- metal_trash_can
	WetFloorSign              = { id = 107435536316777 }, -- WetFloorSign_01
	Table                     = { id = 122521126242415, collide = true, shadow = true }, -- WoodenTable_01
	Table2                    = { id = 123419682616772, collide = true, shadow = true, height = 2.6 }, -- WoodenTable_02
	Chair                     = { id = 80649589645922, collide = true, shadow = true }, -- painted_wooden_chair_01
	Chair2                    = { id = 112600921595081, collide = true, shadow = true }, -- painted_wooden_chair_02
	ArmChair                  = { id = 88145396024229, collide = true, shadow = true }, -- ArmChair_01
	Sofa                      = { id = 79468777414524, collide = true, shadow = true }, -- Sofa_01
	Sofa2                     = { id = 133723905884518, collide = true, shadow = true }, -- sofa_02
	CoffeeTable               = { id = 137973075496954, collide = true, shadow = true }, -- CoffeeTable_01
	SideTable                 = { id = 86712479843395, collide = true }, -- side_table_01
	CeilingLamp               = { id = 98027871412059 }, -- modern_ceiling_lamp_01
	HangingLamp               = { id = 124810221769461 }, -- hanging_industrial_lamp
	PictureFrame              = { id = 81473145650091 }, -- hanging_picture_frame_01
	FramedPicture             = { id = 130744622926853, height = 3.0 }, -- fancy_picture_frame_01
	Mirror                    = { id = 120484942977643, height = 6.0 }, -- ornate_mirror_01
	WhaleStatue               = { id = 116718562861995, collide = true, shadow = true }, -- bronze_whale_statue
	RayStatue                 = { id = 87190526341526, collide = true, shadow = true }, -- bronze_ray_statue
	Vase1                     = { id = 87120354073238 }, -- ceramic_vase_01
	Vase2                     = { id = 130031543289854 }, -- ceramic_vase_02
	Vase4                     = { id = 102825265055851 }, -- ceramic_vase_04
	PlanterPot                = { id = 124661438204654, collide = true, shadow = true, height = 3.0 }, -- planter_pot_clay
	PlanterBox                = { id = 113872556961325, collide = true, shadow = true, height = 3.0 }, -- planter_box_01
	PottedPlant               = { id = 89872840198833, collide = true, shadow = true, height = 5.0 }, -- potted_plant_04
	Fern                      = { id = 135549914398327, height = 2.4 }, -- fern_02
	GrandfatherClock          = { id = 84888811691565, collide = true, shadow = true }, -- vintage_grandfather_clock_01
	Ottoman                   = { id = 78973120937191, collide = true }, -- Ottoman_01
	GreenChair                = { id = 78669780292687, collide = true, shadow = true }, -- GreenChair_01
	MonoblocChair             = { id = 86571827154400, collide = true, shadow = true }, -- plastic_monobloc_chair_01
	DiningTable               = { id = 94741391255177, collide = true, shadow = true }, -- dining_table
	Bench                     = { id = 86648726154092, collide = true, shadow = true }, -- painted_wooden_bench
	Stool                     = { id = 74494801771360, collide = true }, -- painted_wooden_stool
	PicnicTable               = { id = 97016302613378, collide = true, shadow = true }, -- wooden_picnic_table
	Football                  = { id = 105621271624992 }, -- football
	AmericanFootball          = { id = 123915785017900 }, -- american_football
	Baseball                  = { id = 109187983055213, height = 0.6 }, -- baseball_01
	Dartboard                 = { id = 106988540336353 }, -- dartboard
	Shrub                     = { id = 71075652346137, height = 2.4 }, -- shrub_sorrel_01
	Flowers                   = { id = 90264835526433, height = 2.2 }, -- flower_empodium
	SecurityLight             = { id = 104637861058231 }, -- security_light
	IndustrialLamp            = { id = 103547721975286 }, -- industrial_wall_lamp
	DayBed                    = { id = 116924375324086, collide = true, shadow = true }, -- vintage_day_bed
	Nightstand                = { id = 130982122619949, collide = true }, -- ClassicNightstand_01
	Cabinet                   = { id = 83654954415616, collide = true, shadow = true }, -- painted_wooden_cabinet_02
	Drawer                    = { id = 82735970642864, collide = true, shadow = true }, -- vintage_wooden_drawer_01
	Pillows                   = { id = 127318947076582 }, -- throw_pillows_01
	Boombox                   = { id = 90347549099634 }, -- boombox
	Television                = { id = 122585087743766, height = 3.0 }, -- Television_01
	LoungeChair               = { id = 122382011809504, collide = true, shadow = true }, -- mid_century_lounge_chair
	ModernCoffeeTable         = { id = 137187962446170, collide = true, shadow = true }, -- modern_coffee_table_01
	WoodenTable               = { id = 109570767950582, collide = true }, -- wooden_table_02
	PaintedWoodenNightstand   = { id = 93442239894311, collide = true }, -- painted_wooden_nightstand
	PaintedWoodenTable        = { id = 73281471038236, collide = true, shadow = true }, -- painted_wooden_table
	ChineseSofa               = { id = 86656395758763, collide = true, shadow = true }, -- chinese_sofa
	ChineseStool              = { id = 105576794308039, collide = true }, -- chinese_stool
	RollershutterDoor         = { id = 71432382047330, collide = true, shadow = true }, -- rollershutter_door
	RollershutterWindow       = { id = 96940771997953, collide = true, shadow = true }, -- rollershutter_window_01
	RollershutterWindow2      = { id = 118898409844007, collide = true, shadow = true }, -- rollershutter_window_02
	RollershutterWindow3      = { id = 79993644194357, collide = true, shadow = true }, -- rollershutter_window_03
	Barrel                    = { id = 133899554557704, collide = true, shadow = true }, -- barrel_03
	StandingPictureFrame      = { id = 111567700931369 }, -- standing_picture_frame_01
	Croissant                 = { id = 90439090296327 }, -- croissant
	SweetPotato               = { id = 101246293501657 }, -- sweet_potato
	CarvedWoodenPlate         = { id = 113347176765966 }, -- carved_wooden_plate
	PaintedWoodenCabinet      = { id = 106147574838260, collide = true, shadow = true }, -- painted_wooden_cabinet
	WoodenTable2              = { id = 101465571839901, collide = true, shadow = true }, -- WoodenTable_03
	Television2               = { id = 113224179502561 }, -- television_02
	ChineseTeaTable           = { id = 79841599650972 }, -- chinese_tea_table
	BrassVase                 = { id = 71590110754829 }, -- brass_vase_03
	BaseballBat               = { id = 130491325848649, shadow = true }, -- baseball_bat
	ChineseArmchair           = { id = 130355856586901, collide = true, shadow = true }, -- chinese_armchair
	Barrel2                   = { id = 137466861438801, collide = true, shadow = true }, -- Barrel_01
	Barrel3                   = { id = 100228655878895, collide = true, shadow = true }, -- Barrel_02
	CarvedWoodenElephant      = { id = 71500731093006 }, -- carved_wooden_elephant
	BrassVase2                = { id = 117118221566481 }, -- brass_vase_04
	CeramicVase               = { id = 107242389929769 }, -- ceramic_vase_03
	OldTyre                   = { id = 138750461099167, collide = true }, -- old_tyre
	StandingPictureFrame2     = { id = 83371553583632 }, -- standing_picture_frame_02
	WoodenDisplayShelves      = { id = 131105447179036, collide = true, shadow = true }, -- wooden_display_shelves_01
	Plunger                   = { id = 82952335344759 }, -- plunger
	WoodenCandlestick         = { id = 92341578491112 }, -- wooden_candlestick
	BrassPot                  = { id = 116477191696998 }, -- brass_pot_02
	SmallWoodenTable          = { id = 120402394704423 }, -- small_wooden_table_01
	WoodenCuttingBoard        = { id = 77026380912130 }, -- wooden_cutting_board
	CeramicPot                = { id = 128976646539588 }, -- ceramic_pot
	HangingPictureFrame       = { id = 121776581363585 }, -- hanging_picture_frame_02
	BrassPot2                 = { id = 113372792848583 }, -- brass_pot_01
	GothicCommode             = { id = 126589965258040, collide = true, shadow = true }, -- GothicCommode_01
	Lemon                     = { id = 110633496676342 }, -- lemon
	CoffeeTableRound          = { id = 70882963582266 }, -- coffee_table_round_01
	PlasticContainer          = { id = 113477650901770 }, -- plastic_container
	VintagePocketWatch        = { id = 94192815591693 }, -- vintage_pocket_watch
	RoundWoodenTable          = { id = 138287887381487, collide = true }, -- round_wooden_table_02
	BarberShopChair           = { id = 138665121076198, collide = true, shadow = true }, -- BarberShopChair_01
	Dustpan                   = { id = 124371627845930 }, -- dustpan
	BrassPan                  = { id = 118908440668679 }, -- brass_pan_01
	PasticTorch6v             = { id = 96431669084464 }, -- pastic_torch_6v
	VintageStapler            = { id = 102526825700317 }, -- vintage_stapler
	Lightbulb                 = { id = 88377644599277 }, -- lightbulb_01
	UtilityBox                = { id = 79909879419835, collide = true, shadow = true }, -- utility_box_01
	Trashbag                  = { id = 133628495248093 }, -- trashbag
	WoodenBowl                = { id = 104633307513995 }, -- wooden_bowl_02
	CassettePlayer            = { id = 123785149146047 }, -- cassette_player
	WoodenBucket              = { id = 103962641021836 }, -- wooden_bucket_01
	WoodenCrate               = { id = 74118742326619 }, -- wooden_crate_02
	YellowOnion               = { id = 129159045306001 }, -- yellow_onion
	GallineraTable            = { id = 76002482768354 }, -- gallinera_table
	Jug                       = { id = 86572501144001 }, -- jug_01
	PaintedWoodenSofa         = { id = 95908870932684, collide = true, shadow = true }, -- painted_wooden_sofa
	PlasticCrate              = { id = 125744390275225 }, -- plastic_crate_02
	LanternChandelier         = { id = 124300527624006, collide = true, shadow = true }, -- lantern_chandelier_01
	MetalJug                  = { id = 120279096603553 }, -- metal_jug
	WoodenLadder              = { id = 103098036895687, collide = true, shadow = true }, -- wooden_ladder_02
	UtilityBox2               = { id = 106152410169244, collide = true, shadow = true }, -- utility_box_02
	FoldingWoodenStool        = { id = 76669705345683 }, -- folding_wooden_stool
	WornMetalRack             = { id = 79924212652418, collide = true, shadow = true }, -- worn_metal_rack
	SideTableTall             = { id = 92153216784490, collide = true }, -- side_table_tall_01
	LightbulbLed              = { id = 128327226815671 }, -- lightbulb_led
	MetalStool                = { id = 113566560285712 }, -- metal_stool_02
	MetalStool2               = { id = 92716018039156, collide = true, shadow = true }, -- metal_stool_03
	WoodenCrate2              = { id = 107814356032114 }, -- wooden_crate_01
	ChineseCommode            = { id = 91478365582567, collide = true, shadow = true }, -- chinese_commode
	FoodLychee                = { id = 123847040107892 }, -- food_lychee_01
	GardenGloves              = { id = 130165421270216 }, -- garden_gloves_01
	BrassVase3                = { id = 87396335003397 }, -- brass_vase_02
	FoodApple                 = { id = 112246888760470 }, -- food_apple_01
	IndustrialPasticContainer = { id = 72582022402686 }, -- industrial_pastic_container
	FoodGinger                = { id = 77424293754227 }, -- food_ginger_01
	VintageOilLamp            = { id = 78188524854371 }, -- vintage_oil_lamp
	WoodenBucket2             = { id = 87673324748997 }, -- wooden_bucket_02
	SungkaBoard               = { id = 111094408756931 }, -- sungka_board
	BronzeSharkStatue         = { id = 140091259593047 }, -- bronze_shark_statue
	ClassicConsole            = { id = 104451405523040, collide = true, shadow = true }, -- ClassicConsole_01
	FoodAvocado               = { id = 105421196028104 }, -- food_avocado_01
	FoodKiwi                  = { id = 121911872173631 }, -- food_kiwi_01
	ChineseChandelier         = { id = 125953147604345, collide = true }, -- chinese_chandelier
	Sofa3                     = { id = 75682423739324, collide = true, shadow = true }, -- sofa_03
	ModernArmChair            = { id = 103428565530498, collide = true, shadow = true }, -- modern_arm_chair_01
	SteelFrameShelves         = { id = 136669220596273, collide = true, shadow = true }, -- steel_frame_shelves_03
	AlarmClock                = { id = 86538176871971 }, -- alarm_clock_01
	PlanterBox2               = { id = 121337906887883 }, -- planter_box_02
	PlanterBox3               = { id = 131708045992684, collide = true, shadow = true }, -- planter_box_03
	SeedingTray               = { id = 103628512757548 }, -- seeding_tray_01
	WateringCanMetal          = { id = 123953023853947 }, -- watering_can_metal_01
	GardenSprinkler           = { id = 130021319284331 }, -- garden_sprinkler_01
	GardenHoseWallMounted     = { id = 72323421620622 }, -- garden_hose_wall_mounted_01
	WoodenBroom               = { id = 87552729865250, collide = true, shadow = true }, -- wooden_broom
	MetalToolbox              = { id = 131470902600171 }, -- metal_toolbox
	MetalToolChest            = { id = 108861712435336, collide = true }, -- metal_tool_chest
	HandTruck                 = { id = 104540752748876, collide = true, shadow = true }, -- hand_truck
	WoodenLadder2             = { id = 101760738065472, collide = true, shadow = true }, -- wooden_ladder
	OutdoorTableChairSet      = { id = 107177022426855, collide = true, shadow = true }, -- outdoor_table_chair_set_01
	RoundWoodenTable2         = { id = 111779481315706, collide = true, shadow = true }, -- round_wooden_table_01
	BarChairRound             = { id = 74529803972449, collide = true }, -- bar_chair_round_01
	Rockingchair              = { id = 106102371829921, collide = true, shadow = true }, -- Rockingchair_01
	GothicCabinet             = { id = 135979405685736, collide = true, shadow = true }, -- GothicCabinet_01
	ChineseConsoleTable       = { id = 138628111591661, collide = true }, -- chinese_console_table
	ModernCoffeeTable2        = { id = 121867214998354 }, -- modern_coffee_table_02
	WoodenStool               = { id = 118325736872321 }, -- wooden_stool_01
	WoodenStool2              = { id = 95270805238329 }, -- wooden_stool_02
	GallineraChair            = { id = 127848283075084, collide = true, shadow = true }, -- gallinera_chair
	PotEnamel                 = { id = 80966366010372 }, -- pot_enamel_01
	HamburgerBuns             = { id = 137095347065913 }, -- hamburger_buns
	CarrotCake                = { id = 91423316713312 }, -- carrot_cake
	FoodPearsAsian            = { id = 91394891916025 }, -- food_pears_asian_01
	FoodPomegranate           = { id = 133554564369919 }, -- food_pomegranate_01
	FoodLime                  = { id = 101084756510824 }, -- food_lime_01
	SecurityCamera            = { id = 87648122418410 }, -- security_camera_01
}

local templates: { [string]: Model } = {}

-- Roblox's glTF import gives us a Model of MeshParts. Flatten whatever wrapper
-- LoadAsset returned into one template Model we can clone per placement.
local function loadTemplate(kind: string, spec: Spec): Model?
	local ok, result = pcall(function()
		return InsertService:LoadAsset(spec.id)
	end)
	if not ok or not result then
		warn(("[PropService] %s failed to load (%d): %s"):format(kind, spec.id, tostring(result)))
		return nil
	end

	local template = Instance.new("Model")
	template.Name = "Prop_" .. kind
	local count = 0
	for _, item in (result :: Instance):GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = spec.collide == true
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = spec.shadow == true
			item.Massless = true
			if item:IsA("MeshPart") then
				item.CollisionFidelity = Enum.CollisionFidelity.Box
			end
			item.Parent = template
			count += 1
		end
	end
	(result :: Instance):Destroy()
	if count == 0 then
		warn("[PropService] " .. kind .. " contained no parts")
		template:Destroy()
		return nil
	end
	return template
end

-- Place `model` so the centre of the bottom of its bounding box lands on
-- `target`. Furniture is positioned by where its feet go; a bounding-box
-- centre would sink half of every prop into the floor.
local function standOn(model: Model, target: CFrame, hang: boolean?)
	local box, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local edge = if hang then size.Y / 2 else -size.Y / 2
	local toEdge = pivot:ToObjectSpace(box * CFrame.new(0, edge, 0))
	model:PivotTo(target * toEdge:Inverse())
end

function PropService.Init(map: MapService.Map)
	local requests = map.props
	if not requests or #requests == 0 then
		return
	end

	-- only load the kinds this map actually asks for
	local wanted: { [string]: boolean } = {}
	for _, request in requests do
		wanted[request.kind] = true
	end

	local loaded, failed = 0, 0
	for kind in wanted do
		local spec = KINDS[kind]
		if not spec then
			warn("[PropService] no asset registered for prop kind " .. kind)
			failed += 1
			continue
		end
		local template = loadTemplate(kind, spec)
		if template then
			templates[kind] = template
			loaded += 1
		else
			failed += 1
		end
	end
	if loaded == 0 then
		warn("[PropService] no props loaded; the school keeps its block furniture")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = map.folder

	local placed = 0
	for index, request in requests do
		local template = templates[request.kind]
		if not template then
			continue
		end
		local clone = template:Clone()
		local scale = request.scale or 1
		local spec = KINDS[request.kind]
		if spec.height then
			local _, native = clone:GetBoundingBox()
			if native.Y > 0.01 then
				scale *= spec.height / native.Y
			end
		end
		if scale ~= 1 then
			clone:ScaleTo(scale)
		end
		standOn(clone, request.cframe, request.hang)
		clone.Parent = folder
		if request.fallback then
			request.fallback:Destroy()
		end
		placed += 1
		-- a few hundred meshes in one frame stalls the start of a round
		if index % 40 == 0 then
			task.wait()
		end
	end

	print(("[PropService] placed %d props from %d models (%d unavailable)"):format(placed, loaded, failed))
end

return PropService
