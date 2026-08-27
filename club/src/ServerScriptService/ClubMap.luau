--!strict
-- CULT — the world. An unmarked estate at night, a door that does not open,
-- and behind it a long hall that ends in a rotunda dressed to the last inch.
-- Nothing here explains itself. That is the point.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)

local ClubMap = {}

local STONE = Color3.fromRGB(46, 45, 50)
local STONE_DARK = Color3.fromRGB(28, 27, 32)
local GOLD = Color3.fromRGB(212, 175, 85)
local WALNUT = Color3.fromRGB(46, 32, 21)
local VELVET = Color3.fromRGB(74, 20, 24)
local VOID = Color3.fromRGB(10, 9, 12)

-- hall sits at the far end of a 90-stud hallway running down -Z
local HALL_CENTER = Vector3.new(0, 0, -84)
local HALL_R = 32
local HALL_H = 24
local DOOR_Z = 48

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function tex(target: BasePart, face: Enum.NormalId, id: string, u: number, v: number, tint: Color3?)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = id
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	if tint then
		t.Color3 = tint
	end
	t.Parent = target
end

local function decal(target: BasePart, face: Enum.NormalId, id: string)
	local d = Instance.new("Decal")
	d.Face = face
	d.Texture = id
	d.Parent = target
end

local function signText(parent: BasePart, text: string, color: Color3, face: Enum.NormalId?, size: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Michroma
	label.TextScaled = size == nil
	if size then
		label.TextSize = size
	end
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

-- a flame you can turn on and off (the path torches are a puzzle, not decor)
local function flame(parent: Instance, pos: Vector3, scale: number): BasePart
	local core = part({
		Name = "Flame",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.7, 1.1, 0.7) * scale,
		CFrame = CFrame.new(pos),
		Color = Color3.fromRGB(255, 150, 50),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 70)
	light.Brightness = 1.6 * scale
	light.Range = 16 * scale
	light.Parent = core
	local fire = Instance.new("Fire")
	fire.Size = 3 * scale
	fire.Heat = 6
	fire.Parent = core
	return core
end

local function wallTorch(parent: Instance, pos: Vector3, facing: Vector3): BasePart
	local cf = CFrame.lookAt(pos, pos + facing)
	part({
		Name = "TorchBracket",
		Size = Vector3.new(0.3, 0.3, 1.1),
		CFrame = cf * CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(28), 0, 0),
		Color = Color3.fromRGB(26, 25, 29),
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = parent,
	})
	return flame(parent, pos + facing.Unit * 0.4 + Vector3.new(0, 0.55, 0), 0.8)
end

local function candleCluster(parent: Instance, pos: Vector3, lit: boolean): { BasePart }
	local rng = Random.new(math.floor(pos.X * 7 + pos.Z * 3))
	local candles: { BasePart } = {}
	for _ = 1, rng:NextInteger(3, 5) do
		local ox, oz = rng:NextNumber(-0.9, 0.9), rng:NextNumber(-0.9, 0.9)
		local h = rng:NextNumber(0.5, 1.4)
		local candle = part({
			Name = "Candle",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 0.34, 0.34),
			CFrame = CFrame.new(pos + Vector3.new(ox, h / 2, oz)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(232, 224, 205),
			CanCollide = false,
			Parent = parent,
		})
		table.insert(candles, candle)
		if lit then
			flame(parent, pos + Vector3.new(ox, h + 0.25, oz), 0.28)
		end
	end
	return candles
end

-- ---------------------------------------------------------------- meshes ---
-- GLB import drops glTF material colors, so styles are re-applied by node name
-- with an ordered fallback (same approach that fixed the white meshes before).
type Style = { color: Color3, material: Enum.Material? }

local MESH_STYLES: { [number]: { Style } } = {
	[Config.Meshes.Chandelier] = {
		{ color = GOLD, material = Enum.Material.Metal },
		{ color = Color3.fromRGB(228, 220, 196) },
		{ color = Color3.fromRGB(255, 208, 110), material = Enum.Material.Neon },
	},
	[Config.Meshes.Wingback] = {
		{ color = VELVET, material = Enum.Material.Fabric },
		{ color = WALNUT, material = Enum.Material.Wood },
	},
	[Config.Meshes.Candelabra] = {
		{ color = GOLD, material = Enum.Material.Metal },
		{ color = Color3.fromRGB(228, 220, 196) },
		{ color = Color3.fromRGB(255, 208, 110), material = Enum.Material.Neon },
	},
	[Config.Meshes.Column] = {
		{ color = Color3.fromRGB(58, 56, 60), material = Enum.Material.Marble },
	},
	[Config.Meshes.Tree] = {
		{ color = Color3.fromRGB(46, 36, 27), material = Enum.Material.Wood },
		{ color = Color3.fromRGB(24, 36, 28), material = Enum.Material.Grass },
	},
}

local function loadMesh(assetId: number): Model?
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not asset then
		warn("[CULT] mesh " .. assetId .. " failed to load")
		return nil
	end
	local inner = asset:FindFirstChildOfClass("Model")
	local template = Instance.new("Model")
	for _, child in (inner or asset):GetChildren() do
		if child:IsA("BasePart") or child:IsA("Model") then
			child.Parent = template
		end
	end
	local parts: { BasePart } = {}
	for _, p in template:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = true
			table.insert(parts, p)
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	local styles = MESH_STYLES[assetId]
	if styles then
		for i, p in parts do
			local style = styles[math.min(i, #styles)]
			p.Color = style.color
			if style.material then
				p.Material = style.material
			end
			if style.material == Enum.Material.Neon then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 190, 110)
				light.Brightness = 0.8
				light.Range = 14
				light.Parent = p
			end
		end
	end
	asset:Destroy()
	if #template:GetChildren() == 0 then
		return nil
	end
	return template
end

local function placeMesh(template: Model?, parent: Instance, name: string, cf: CFrame, scale: number): Model?
	if not template then
		return nil
	end
	local clone = template:Clone()
	clone.Name = name
	clone:ScaleTo(scale)
	clone:PivotTo(cf)
	clone.Parent = parent
	return clone
end

-- ---------------------------------------------------------------- grounds ---
export type PathTorch = { flame: BasePart, light: PointLight, fire: Fire }

local function buildGrounds(folder: Folder): ({ PathTorch }, BasePart, BasePart, BasePart)
	part({
		Name = "Grounds",
		Size = Vector3.new(340, 2, 340),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(26, 38, 30),
		Material = Enum.Material.Grass,
		Parent = folder,
	})
	part({
		Name = "ApproachPath",
		Size = Vector3.new(12, 0.4, 76),
		CFrame = CFrame.new(0, 0.05, DOOR_Z + 40),
		Color = Color3.fromRGB(44, 43, 48),
		Material = Enum.Material.Cobblestone,
		Parent = folder,
	})

	-- "the flames that guard the path": nine poles, and the server decides
	-- how many of them burn tonight
	local torches: { PathTorch } = {}
	for i = 0, 8 do
		local z = DOOR_Z + 14 + i * 8
		local x = (i % 2 == 0) and -8.5 or 8.5
		part({
			Name = "TorchPole",
			Size = Vector3.new(0.5, 8, 0.5),
			CFrame = CFrame.new(x, 4, z),
			Color = Color3.fromRGB(26, 25, 29),
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		part({
			Name = "TorchBowl",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 1.5, 1.5),
			CFrame = CFrame.new(x, 8.2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(26, 25, 29),
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		local f = flame(folder, Vector3.new(x, 9, z), 0.9)
		f.Name = "PathFlame"
		torches[i + 1] = {
			flame = f,
			light = f:FindFirstChildOfClass("PointLight") :: PointLight,
			fire = f:FindFirstChildOfClass("Fire") :: Fire,
		}
	end

	-- the obelisk: asks the question whose answer is the torches
	local obelisk = part({
		Name = "Obelisk",
		Size = Vector3.new(4, 22, 4),
		CFrame = CFrame.new(-46, 11, DOOR_Z + 38),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	part({
		Name = "ObeliskCap",
		Size = Vector3.new(2.6, 3.2, 2.6),
		CFrame = CFrame.new(-46, 23.4, DOOR_Z + 38),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	part({
		Name = "ObeliskBase",
		Size = Vector3.new(7, 1.4, 7),
		CFrame = CFrame.new(-46, 0.7, DOOR_Z + 38),
		Color = STONE,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	signText(obelisk, "I\n\nAS MANY AS THE\nFLAMES THAT\nGUARD THE PATH", Color3.fromRGB(150, 128, 82), Enum.NormalId.Right, 34)

	-- the monument: a date that is not a date
	local monument = part({
		Name = "Monument",
		Size = Vector3.new(10, 7, 3),
		CFrame = CFrame.new(46, 3.5, DOOR_Z + 38),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	part({
		Name = "MonumentBase",
		Size = Vector3.new(13, 1.4, 5),
		CFrame = CFrame.new(46, 0.7, DOOR_Z + 38),
		Color = STONE,
		Material = Enum.Material.Slate,
		Parent = folder,
	})

	-- the buried sigil, under one particular tree
	local sigil = part({
		Name = "BuriedSigil",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 9, 9),
		CFrame = CFrame.new(-64, 0.16, 24) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(52, 44, 30),
		Material = Enum.Material.Slate,
		CanCollide = false,
		Parent = folder,
	})
	signText(sigil, "₼", Color3.fromRGB(120, 96, 44), Enum.NormalId.Right)

	return torches, obelisk, monument, sigil
end

local function buildTrees(folder: Folder, template: Model?)
	if not template then
		return
	end
	local rng = Random.new(23)
	-- the marked tree stands over the sigil
	placeMesh(template, folder, "MarkedTree", CFrame.new(-64, 8.6, 24), 1.5)
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local d = rng:NextNumber(88, 132)
		local x, z = math.sin(a) * d, math.cos(a) * d + DOOR_Z
		if math.abs(x) > 22 or z < DOOR_Z - 10 then -- keep the approach clear
			placeMesh(
				template,
				folder,
				"GroundsTree",
				CFrame.new(x, rng:NextNumber(6.5, 10), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rng:NextNumber(0.9, 1.7)
			)
		end
	end
end

-- ----------------------------------------------------------------- facade ---
-- The building is a stepped pyramid now — a monument you can see from anywhere
-- on the grounds, its capstone burning gold against the night. Hollow tiers
-- wrap the hallway and the grand hall; one gap in the lowest tiers holds the
-- door, and the door still only answers to the code.
local PYR_CENTER_Z = -36
local PYR_TIERS = 13
local PYR_TIER_H = 8
local PYR_BASE_HALF = 90
local PYR_TOP_HALF = 10

local function buildFacade(folder: Folder): (BasePart, BasePart, BasePart, { BasePart })
	local function slab(name: string, size: Vector3, cf: CFrame)
		return part({ Name = name, Size = size, CFrame = cf, Color = STONE, Material = Enum.Material.Slate, Parent = folder })
	end
	local thick = 8
	for t = 0, PYR_TIERS - 1 do
		local half = PYR_BASE_HALF - t * (PYR_BASE_HALF - PYR_TOP_HALF) / (PYR_TIERS - 1)
		local y = t * PYR_TIER_H + PYR_TIER_H / 2
		local zc = PYR_CENTER_Z
		-- north face carries the entrance gap through the two lowest tiers
		if t <= 1 then
			local gap = 10
			local segW = half - gap
			slab("PyrN", Vector3.new(segW, PYR_TIER_H, thick), CFrame.new(-(gap + segW / 2), y, zc + half - thick / 2))
			slab("PyrN", Vector3.new(segW, PYR_TIER_H, thick), CFrame.new(gap + segW / 2, y, zc + half - thick / 2))
		else
			slab("PyrN", Vector3.new(half * 2, PYR_TIER_H, thick), CFrame.new(0, y, zc + half - thick / 2))
		end
		slab("PyrS", Vector3.new(half * 2, PYR_TIER_H, thick), CFrame.new(0, y, zc - half + thick / 2))
		slab("PyrE", Vector3.new(thick, PYR_TIER_H, half * 2 - thick * 2), CFrame.new(half - thick / 2, y, zc))
		slab("PyrW", Vector3.new(thick, PYR_TIER_H, half * 2 - thick * 2), CFrame.new(-(half - thick / 2), y, zc))
	end
	-- lintel sealing the top of the entrance gap
	local lintel = slab("PyrLintel", Vector3.new(20, 4, thick), CFrame.new(0, PYR_TIER_H * 2 + 2, PYR_CENTER_Z + PYR_BASE_HALF - thick / 2))
	-- the capstone burns
	local capY = PYR_TIERS * PYR_TIER_H
	part({
		Name = "Capstone",
		Size = Vector3.new(PYR_TOP_HALF * 2, 6, PYR_TOP_HALF * 2),
		CFrame = CFrame.new(0, capY + 3, PYR_CENTER_Z),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local capLight = Instance.new("PointLight")
	capLight.Color = Color3.fromRGB(255, 200, 100)
	capLight.Brightness = 3
	capLight.Range = 60
	capLight.Parent = folder:FindFirstChild("Capstone")
	flame(folder, Vector3.new(0, capY + 8, PYR_CENTER_Z), 2.4)
	-- the eye: a gold sigil over the entrance
	local eye = part({
		Name = "PyramidEye",
		Size = Vector3.new(10, 10, 0.6),
		CFrame = CFrame.new(0, 34, PYR_CENTER_Z + PYR_BASE_HALF - 12),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
		CanCollide = false,
		Parent = folder,
	})
	signText(eye, "▲", GOLD, Enum.NormalId.Front)

	-- the door: two slabs that will part when the code is right
	local doorL = part({
		Name = "DoorL",
		Size = Vector3.new(6, 14, 1.2),
		CFrame = CFrame.new(-3, 7, DOOR_Z),
		Color = Color3.fromRGB(34, 24, 16),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	local doorR = part({
		Name = "DoorR",
		Size = Vector3.new(6, 14, 1.2),
		CFrame = CFrame.new(3, 7, DOOR_Z),
		Color = Color3.fromRGB(34, 24, 16),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	for _, d in { doorL, doorR } do
		tex(d, Enum.NormalId.Front, Config.Textures.Wainscot, 6, 14)
		tex(d, Enum.NormalId.Back, Config.Textures.Wainscot, 6, 14)
	end
	part({
		Name = "DoorRing",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		CFrame = CFrame.new(-1.2, 7, DOOR_Z - 0.8),
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = folder,
	})

	-- three portraits weather the pyramid's north face. one is hung wrong.
	local portraits: { BasePart } = {}
	local ids = { Config.Textures.Portrait1, Config.Textures.Portrait2, Config.Textures.Portrait3 }
	local faceZ = PYR_CENTER_Z + PYR_BASE_HALF + 0.4
	for i, x in { -30, -19, 30 } do
		local flipped = (i == 2)
		local p = part({
			Name = flipped and "PortraitWrong" or ("Portrait" .. i),
			Size = Vector3.new(5, 6.25, 0.5),
			CFrame = CFrame.new(x, 5, faceZ) * CFrame.Angles(0, 0, flipped and math.pi or 0),
			Color = VOID,
			Material = Enum.Material.Wood,
			CanCollide = false,
			Parent = folder,
		})
		decal(p, Enum.NormalId.Front, ids[i])
		table.insert(portraits, p)
	end

	return doorL, doorR, lintel, portraits
end

local function buildKeypad(folder: Folder): BasePart
	part({
		Name = "KeypadPlinth",
		Size = Vector3.new(3, 4.4, 3),
		CFrame = CFrame.new(13, 2.2, DOOR_Z + 11),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	local pad = part({
		Name = "Keypad",
		Size = Vector3.new(2.6, 3.4, 0.5),
		CFrame = CFrame.new(13, 5.6, DOOR_Z + 11) * CFrame.Angles(math.rad(-22), 0, 0),
		Color = Color3.fromRGB(20, 19, 23),
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	part({
		Name = "KeypadFrame",
		Size = Vector3.new(3.1, 3.9, 0.4),
		CFrame = pad.CFrame * CFrame.new(0, 0, 0.16),
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = folder,
	})
	return pad
end

-- --------------------------------------------------------------- hallway ---
local function buildHallway(folder: Folder)
	local zStart, zEnd = DOOR_Z, HALL_CENTER.Z + HALL_R + 4
	local length = zStart - zEnd
	local mid = (zStart + zEnd) / 2

	local floor = part({
		Name = "HallFloor",
		Size = Vector3.new(10, 1, length),
		CFrame = CFrame.new(0, -0.5, mid),
		Color = WALNUT,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	tex(floor, Enum.NormalId.Top, Config.Textures.Parquet, 10, 10)

	local ceiling = part({
		Name = "HallCeiling",
		Size = Vector3.new(10, 1, length),
		CFrame = CFrame.new(0, 10.5, mid),
		Color = Color3.fromRGB(26, 20, 15),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	tex(ceiling, Enum.NormalId.Bottom, Config.Textures.Coffer, 10, 10)

	for _, side in { -1, 1 } do
		local wall = part({
			Name = "HallWall",
			Size = Vector3.new(1, 11, length),
			CFrame = CFrame.new(side * 5.5, 5, mid),
			Color = WALNUT,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		local face = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
		tex(wall, face, Config.Textures.Wainscot, 11, 11)
	end

	-- torches every eight studs, and portraits watching between them
	local ids = { Config.Textures.Portrait1, Config.Textures.Portrait2, Config.Textures.Portrait3 }
	local n = math.floor(length / 8)
	for i = 0, n do
		local z = zStart - 6 - i * 8
		if z <= zEnd + 4 then
			break
		end
		local side = (i % 2 == 0) and -1 or 1
		wallTorch(folder, Vector3.new(side * 4.7, 7, z), Vector3.new(-side, 0, 0))
		if i % 2 == 1 then
			local p = part({
				Name = "HallPortrait",
				Size = Vector3.new(0.4, 5, 4),
				CFrame = CFrame.new(-side * 4.72, 5.6, z),
				Color = VOID,
				Material = Enum.Material.Wood,
				CanCollide = false,
				Parent = folder,
			})
			decal(p, side < 0 and Enum.NormalId.Left or Enum.NormalId.Right, ids[(i % 3) + 1])
		end
	end
end

-- ------------------------------------------------------------ grand hall ---
export type Gate = { door: BasePart, rank: string, label: string }

local function buildGrandHall(
	folder: Folder,
	meshes: { [string]: Model? }
): ({ Seat }, BasePart, { Gate }, BasePart, BasePart?)
	local cx, cz = HALL_CENTER.X, HALL_CENTER.Z
	local segW = 2 * HALL_R * math.tan(math.pi / 8) + 2

	local floor = part({
		Name = "GrandFloor",
		Size = Vector3.new(HALL_R * 2 + 8, 1, HALL_R * 2 + 8),
		CFrame = CFrame.new(cx, -0.5, cz),
		Color = WALNUT,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	tex(floor, Enum.NormalId.Top, Config.Textures.Parquet, 12, 12)

	local ceiling = part({
		Name = "GrandCeiling",
		Size = Vector3.new(HALL_R * 2 + 8, 1, HALL_R * 2 + 8),
		CFrame = CFrame.new(cx, HALL_H + 0.5, cz),
		Color = Color3.fromRGB(24, 18, 13),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	tex(ceiling, Enum.NormalId.Bottom, Config.Textures.Coffer, 16, 16)

	-- the rug, centred under the circle
	local rug = part({
		Name = "GrandRug",
		Size = Vector3.new(40, 0.12, 25),
		CFrame = CFrame.new(cx, 0.06, cz),
		Color = Color3.fromRGB(120, 40, 40),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = folder,
	})
	decal(rug, Enum.NormalId.Top, Config.Textures.Rug)

	-- octagonal wall: wainscot below, damask above, gilt rail between
	local gates: { Gate } = {}
	local GATE_PLAN: { [number]: { rank: string, label: string } } = {
		[2] = { rank = "INSIDER", label = "THE PRIVATE CORRIDOR" },
		[4] = { rank = "OPERATOR", label = "THE UNDERCROFT" },
		[6] = { rank = "ARCHITECT", label = "THE APEX" },
		[8] = { rank = "INNER CIRCLE", label = "" },
	}
	local missionBoard: BasePart? = nil
	local memberGate: BasePart? = nil

	for i = 1, 8 do
		local a = (i - 1) / 8 * math.pi * 2
		local nx, nz = math.sin(a), math.cos(a)
		local pos = Vector3.new(cx + nx * HALL_R, 0, cz + nz * HALL_R)
		local cf = CFrame.lookAt(pos, pos - Vector3.new(nx, 0, nz))

		local isEntry = (i == 1) -- the segment facing the hallway
		if not isEntry then
			local lower = part({
				Name = "HallWainscot",
				Size = Vector3.new(segW, 9, 1.2),
				CFrame = cf * CFrame.new(0, 4.5, 0),
				Color = WALNUT,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			tex(lower, Enum.NormalId.Back, Config.Textures.Wainscot, 12, 9)
			local upper = part({
				Name = "HallDamask",
				Size = Vector3.new(segW, HALL_H - 9, 1.2),
				CFrame = cf * CFrame.new(0, 9 + (HALL_H - 9) / 2, 0),
				Color = Color3.fromRGB(48, 30, 34),
				Material = Enum.Material.Fabric,
				Parent = folder,
			})
			tex(upper, Enum.NormalId.Back, Config.Textures.Damask, 12, 12)
			part({
				Name = "GiltRail",
				Size = Vector3.new(segW, 0.4, 1.6),
				CFrame = cf * CFrame.new(0, 9.2, 0),
				Color = GOLD,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = folder,
			})
		else
			-- entry arch back to the hallway
			for _, side in { -1, 1 } do
				part({
					Name = "EntryJamb",
					Size = Vector3.new((segW - 10) / 2, HALL_H, 1.2),
					CFrame = cf * CFrame.new(side * (segW / 2 - (segW - 10) / 4), HALL_H / 2, 0),
					Color = WALNUT,
					Material = Enum.Material.Wood,
					Parent = folder,
				})
			end
			part({
				Name = "EntryLintel",
				Size = Vector3.new(10, HALL_H - 12, 1.2),
				CFrame = cf * CFrame.new(0, 12 + (HALL_H - 12) / 2, 0),
				Color = WALNUT,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			-- the hall itself is for MEMBERS: initiates walk the hallway and
			-- stop here, at a door that knows how many hours they have served
			memberGate = part({
				Name = "MemberGate",
				Size = Vector3.new(10, 12, 1),
				CFrame = cf * CFrame.new(0, 6, 0),
				Color = Color3.fromRGB(24, 17, 12),
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			tex(memberGate :: BasePart, Enum.NormalId.Front, Config.Textures.Wainscot, 10, 12)
			tex(memberGate :: BasePart, Enum.NormalId.Back, Config.Textures.Wainscot, 10, 12)
			signText(memberGate :: BasePart, "▲", GOLD, Enum.NormalId.Front, 60)
		end

		-- fluted column at every vertex
		local va = (i - 1) / 8 * math.pi * 2 + math.pi / 8
		placeMesh(
			meshes.column,
			folder,
			"HallColumn",
			CFrame.new(cx + math.sin(va) * (HALL_R - 2.5), 0, cz + math.cos(va) * (HALL_R - 2.5)),
			HALL_H / 11.7
		)
		-- candelabra between the columns
		if not isEntry then
			placeMesh(meshes.candelabra, folder, "HallCandelabra", cf * CFrame.new(-9, 0, 3), 1.1)
			placeMesh(meshes.candelabra, folder, "HallCandelabra", cf * CFrame.new(9, 0, 3), 1.1)
		end

		local plan = GATE_PLAN[i]
		if plan then
			local door = part({
				Name = "Gate_" .. plan.rank,
				Size = Vector3.new(8, 12, 0.8),
				CFrame = cf * CFrame.new(0, 6, -1),
				Color = Color3.fromRGB(28, 20, 14),
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			tex(door, Enum.NormalId.Back, Config.Textures.Wainscot, 8, 12)
			if plan.label ~= "" then
				local plaque = part({
					Name = "GatePlaque",
					Size = Vector3.new(6, 1.1, 0.3),
					CFrame = cf * CFrame.new(0, 13, -1.2),
					Color = Color3.fromRGB(20, 19, 23),
					Material = Enum.Material.Metal,
					CanCollide = false,
					Parent = folder,
				})
				signText(plaque, plan.label, GOLD, Enum.NormalId.Back, 26)
			end
			table.insert(gates, { door = door :: BasePart, rank = plan.rank, label = plan.label })
		elseif i == 5 then
			-- fireplace opposite the entry
			part({
				Name = "Fireplace",
				Size = Vector3.new(12, 9, 2),
				CFrame = cf * CFrame.new(0, 4.5, -1.2),
				Color = STONE_DARK,
				Material = Enum.Material.Slate,
				Parent = folder,
			})
			part({
				Name = "FireplaceMouth",
				Size = Vector3.new(7, 5.5, 1.4),
				CFrame = cf * CFrame.new(0, 2.75, -1.9),
				Color = VOID,
				Material = Enum.Material.Slate,
				CanCollide = false,
				Parent = folder,
			})
			part({
				Name = "Mantel",
				Size = Vector3.new(14, 0.8, 3),
				CFrame = cf * CFrame.new(0, 9.3, -1.2),
				Color = WALNUT,
				Material = Enum.Material.Wood,
				CanCollide = false,
				Parent = folder,
			})
			flame(folder, (cf * CFrame.new(0, 1.8, -1.9)).Position, 1.5)
			candleCluster(folder, (cf * CFrame.new(-5, 9.8, -1.2)).Position, true)
			candleCluster(folder, (cf * CFrame.new(5, 9.8, -1.2)).Position, true)
		elseif i == 3 then
			-- the board where the missions are posted
			local board = part({
				Name = "MissionBoard",
				Size = Vector3.new(14, 9, 0.6),
				CFrame = cf * CFrame.new(0, 7, -1),
				Color = Color3.fromRGB(22, 16, 12),
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			part({
				Name = "BoardFrame",
				Size = Vector3.new(15, 10, 0.4),
				CFrame = cf * CFrame.new(0, 7, -0.7),
				Color = GOLD,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = folder,
			})
			missionBoard = board
		else
			-- ancestor portraits between the gates
			local ids = { Config.Textures.Portrait1, Config.Textures.Portrait2, Config.Textures.Portrait3 }
			for _, ox in { -8, 8 } do
				local p = part({
					Name = "HallPortrait",
					Size = Vector3.new(5.6, 7, 0.5),
					CFrame = cf * CFrame.new(ox, 13, -1.3),
					Color = VOID,
					Material = Enum.Material.Wood,
					CanCollide = false,
					Parent = folder,
				})
				decal(p, Enum.NormalId.Back, ids[((ox > 0) and 1 or 3)])
			end
		end
	end

	-- chandeliers
	placeMesh(meshes.chandelier, folder, "GrandChandelier", CFrame.new(cx - 13, HALL_H - 9, cz), 2.6)
	placeMesh(meshes.chandelier, folder, "GrandChandelier", CFrame.new(cx + 13, HALL_H - 9, cz), 2.6)

	-- the altar: a raised dais with a standing flame
	part({
		Name = "AltarDais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 13, 13),
		CFrame = CFrame.new(cx, 0.7, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE_DARK,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	local altar = part({
		Name = "Altar",
		Size = Vector3.new(4.5, 4, 4.5),
		CFrame = CFrame.new(cx, 3.4, cz),
		Color = STONE_DARK,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	part({
		Name = "AltarBowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 3.4, 3.4),
		CFrame = CFrame.new(cx, 5.7, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = folder,
	})
	local altarFlame = flame(folder, Vector3.new(cx, 7, cz), 1.8)
	altarFlame.Name = "AltarFlame"

	-- the circle: twelve chairs facing in
	local chairs: { Seat } = {}
	for i = 1, 12 do
		local a = (i - 1) / 12 * math.pi * 2
		local pos = Vector3.new(cx + math.sin(a) * 15, 0, cz + math.cos(a) * 15)
		local facing = CFrame.lookAt(pos, Vector3.new(cx, 0, cz))
		placeMesh(meshes.wingback, folder, "CircleChair", facing * CFrame.Angles(0, math.pi, 0), 1.05)
		local seat = Instance.new("Seat")
		seat.Name = (i == 12) and "ReservedSeat" or ("CircleSeat" .. i)
		seat.Size = Vector3.new(3, 0.4, 3)
		seat.CFrame = facing * CFrame.new(0, 1.6, 0)
		seat.Anchored = true
		seat.Transparency = 1
		seat.Parent = folder
		chairs[i] = seat
	end

	-- three candles that never burn (a mission lives here)
	for _, spot in { Vector3.new(cx - 24, 0.1, cz - 8), Vector3.new(cx + 24, 0.1, cz + 8), Vector3.new(cx, 0.1, cz + 26) } do
		local unlit = candleCluster(folder, spot, false)
		for _, c in unlit do
			c.Name = "ColdCandle"
		end
	end

	return chairs, altar, gates, missionBoard or altar, memberGate
end

-- ------------------------------------------------------------------ build ---
export type Map = {
	folder: Folder,
	pathTorches: { PathTorch },
	obelisk: BasePart,
	monument: BasePart,
	sigil: BasePart,
	keypad: BasePart,
	doorL: BasePart,
	doorR: BasePart,
	wrongPortrait: BasePart,
	chairs: { Seat },
	altar: BasePart,
	gates: { Gate },
	missionBoard: BasePart,
	memberGate: BasePart?,
	hallCenter: Vector3,
	entryPoint: Vector3,
	hallPoint: Vector3,
}

function ClubMap.Build(): Map
	local folder = Instance.new("Folder")
	folder.Name = "CULT"
	folder.Parent = workspace

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Approach"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, DOOR_Z + 78)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	local pathTorches, obelisk, monument, sigil = buildGrounds(folder)
	local doorL, doorR, _lintel, portraits = buildFacade(folder)
	local keypad = buildKeypad(folder)
	buildHallway(folder)

	local meshes = {
		column = loadMesh(Config.Meshes.Column),
		chandelier = loadMesh(Config.Meshes.Chandelier),
		candelabra = loadMesh(Config.Meshes.Candelabra),
		wingback = loadMesh(Config.Meshes.Wingback),
	}
	local chairs, altar, gates, missionBoard, memberGate = buildGrandHall(folder, meshes)
	buildTrees(folder, loadMesh(Config.Meshes.Tree))

	local wrong = folder:FindFirstChild("PortraitWrong") :: BasePart
	return {
		folder = folder,
		pathTorches = pathTorches,
		obelisk = obelisk,
		monument = monument,
		sigil = sigil,
		keypad = keypad,
		doorL = doorL,
		doorR = doorR,
		wrongPortrait = wrong or portraits[2],
		chairs = chairs,
		altar = altar,
		gates = gates,
		missionBoard = missionBoard,
		memberGate = memberGate,
		hallCenter = HALL_CENTER,
		entryPoint = Vector3.new(0, 3, DOOR_Z - 6),
		hallPoint = Vector3.new(HALL_CENTER.X, 3, HALL_CENTER.Z + 22),
	}
end

return ClubMap
