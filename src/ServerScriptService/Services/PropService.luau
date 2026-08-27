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
	SchoolDesk        = { id = 126069129781784, collide = true, shadow = true }, -- SchoolDesk_01
	SchoolChair       = { id = 86158548904779, collide = true, shadow = true }, -- SchoolChair_01
	OfficeDesk        = { id = 117814615626586, collide = true, shadow = true }, -- metal_office_desk
	Chalkboard        = { id = 139944048015518, collide = true, shadow = true }, -- standing_chalkboard_01
	ProjectorScreen   = { id = 131655294209917, collide = true, shadow = true }, -- projector_screen
	Bookshelf         = { id = 111602596532178, collide = true, shadow = true }, -- wooden_bookshelf_worn
	Shelf             = { id = 137144936926067, collide = true }, -- Shelf_01
	SteelShelves      = { id = 91674694775035, collide = true, shadow = true, height = 7.6 }, -- steel_frame_shelves_01
	SteelShelves2     = { id = 99718506671397, collide = true, shadow = true }, -- steel_frame_shelves_02
	Clock             = { id = 106161527319573 }, -- wall_clock
	Laptop            = { id = 96677810707224 }, -- classic_laptop
	Stationery        = { id = 100753846020322 }, -- stationery_supplies
	Notepads          = { id = 105565813304178 }, -- office_notepads
	Clipboard         = { id = 90168931687194 }, -- clipboard
	BunsenBurner      = { id = 81032639006463, height = 1.6 }, -- bunsen_burner
	FireAlarm         = { id = 98131827261163 }, -- fire_alarm
	Extinguisher      = { id = 131695449907539 }, -- korean_fire_extinguisher_01
	Bin               = { id = 126919211473706, collide = true, shadow = true }, -- metal_trash_can
	WetFloorSign      = { id = 107435536316777 }, -- WetFloorSign_01
	Table             = { id = 122521126242415, collide = true, shadow = true }, -- WoodenTable_01
	Table2            = { id = 123419682616772, collide = true, shadow = true, height = 2.6 }, -- WoodenTable_02
	Chair             = { id = 80649589645922, collide = true, shadow = true }, -- painted_wooden_chair_01
	Chair2            = { id = 112600921595081, collide = true, shadow = true }, -- painted_wooden_chair_02
	ArmChair          = { id = 88145396024229, collide = true, shadow = true }, -- ArmChair_01
	Sofa              = { id = 79468777414524, collide = true, shadow = true }, -- Sofa_01
	Sofa2             = { id = 133723905884518, collide = true, shadow = true }, -- sofa_02
	CoffeeTable       = { id = 137973075496954, collide = true, shadow = true }, -- CoffeeTable_01
	SideTable         = { id = 86712479843395, collide = true }, -- side_table_01
	CeilingLamp       = { id = 98027871412059 }, -- modern_ceiling_lamp_01
	HangingLamp       = { id = 124810221769461 }, -- hanging_industrial_lamp
	PictureFrame      = { id = 81473145650091 }, -- hanging_picture_frame_01
	FramedPicture     = { id = 130744622926853, height = 3.0 }, -- fancy_picture_frame_01
	Mirror            = { id = 120484942977643, height = 6.0 }, -- ornate_mirror_01
	WhaleStatue       = { id = 116718562861995, collide = true, shadow = true }, -- bronze_whale_statue
	RayStatue         = { id = 87190526341526, collide = true, shadow = true }, -- bronze_ray_statue
	Vase1             = { id = 87120354073238 }, -- ceramic_vase_01
	Vase2             = { id = 130031543289854 }, -- ceramic_vase_02
	Vase4             = { id = 102825265055851 }, -- ceramic_vase_04
	PlanterPot        = { id = 124661438204654, collide = true, shadow = true, height = 3.0 }, -- planter_pot_clay
	PlanterBox        = { id = 113872556961325, collide = true, shadow = true, height = 3.0 }, -- planter_box_01
	PottedPlant       = { id = 89872840198833, collide = true, shadow = true, height = 5.0 }, -- potted_plant_04
	Fern              = { id = 135549914398327, height = 2.4 }, -- fern_02
	GrandfatherClock  = { id = 84888811691565, collide = true, shadow = true }, -- vintage_grandfather_clock_01
	Ottoman           = { id = 78973120937191, collide = true }, -- Ottoman_01
	GreenChair        = { id = 78669780292687, collide = true, shadow = true }, -- GreenChair_01
	MonoblocChair     = { id = 86571827154400, collide = true, shadow = true }, -- plastic_monobloc_chair_01
	DiningTable       = { id = 94741391255177, collide = true, shadow = true }, -- dining_table
	Bench             = { id = 86648726154092, collide = true, shadow = true }, -- painted_wooden_bench
	Stool             = { id = 74494801771360, collide = true }, -- painted_wooden_stool
	PicnicTable       = { id = 97016302613378, collide = true, shadow = true }, -- wooden_picnic_table
	Football          = { id = 105621271624992 }, -- football
	AmericanFootball  = { id = 123915785017900 }, -- american_football
	Baseball          = { id = 109187983055213, height = 0.6 }, -- baseball_01
	Dartboard         = { id = 106988540336353 }, -- dartboard
	Shrub             = { id = 71075652346137, height = 2.4 }, -- shrub_sorrel_01
	Flowers           = { id = 90264835526433, height = 2.2 }, -- flower_empodium
	SecurityLight     = { id = 104637861058231 }, -- security_light
	IndustrialLamp    = { id = 103547721975286 }, -- industrial_wall_lamp
	DayBed            = { id = 116924375324086, collide = true, shadow = true }, -- vintage_day_bed
	Nightstand        = { id = 130982122619949, collide = true }, -- ClassicNightstand_01
	Cabinet           = { id = 83654954415616, collide = true, shadow = true }, -- painted_wooden_cabinet_02
	Drawer            = { id = 82735970642864, collide = true, shadow = true }, -- vintage_wooden_drawer_01
	Pillows           = { id = 127318947076582 }, -- throw_pillows_01
	Boombox           = { id = 90347549099634 }, -- boombox
	Television        = { id = 122585087743766, height = 3.0 }, -- Television_01
	LoungeChair       = { id = 122382011809504, collide = true, shadow = true }, -- mid_century_lounge_chair
	ModernCoffeeTable = { id = 137187962446170, collide = true, shadow = true }, -- modern_coffee_table_01
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
