--!strict
-- THE SANCTUM -- the estate we designed for the robes game, buried under the
-- school and reached by the stair behind the principal's bookshelf.
--
-- This is ClubMap from that project, brought across whole: a granite ground, a
-- marble boulevard of reflecting pools and colonnades, obelisks and crystal,
-- and at the end of it a white pyramid with a burning gold capstone. Inside,
-- the chambers still ascend by tier -- Grand Hall, Gold, Platinum, Black, and
-- the Crown at the point.
--
-- Two things changed and nothing else. Every part is placed through a single
-- transform, so the whole estate is built at SCALE and dropped at ORIGIN
-- rather than rewriting a thousand coordinates; and the tier gates are open,
-- because there is no membership roster in this game -- if you found the
-- bookshelf and you know the code, the whole place is yours.
--
-- It is sealed inside its own cavern. The complaint that started this was that
-- the old chamber hung in the open under the school, visible from outside and
-- with a hole in its ceiling.

local InsertService = game:GetService("InsertService")

local SanctumMap = {}

-- 0.6 of the original, turned a quarter turn and buried under the LIBRARY: the
-- pyramid's centre sits directly beneath the reading room, its capstone thirty
-- studs under the floorboards, and the boulevard runs away west under the
-- north field. The quarter turn is what puts the boulevard on the west side,
-- where the tunnel from the headmaster's office comes in.
local SCALE = 0.6
local ORIGIN = Vector3.new(-48, -120, -232)
-- Turned so the estate's own +Z (the boulevard, running away from the pyramid)
-- points along world -X.
local YAW = -math.pi / 2
local ROT = CFrame.Angles(0, YAW, 0)

-- A point in the estate's own coordinates, in world space. Everything BUILT
-- here goes through place() below, but the landing points handed back to the
-- caller did not: they were raw estate coordinates like (0, 55, -114), which
-- as world coordinates is fifty-five studs above the school courtyard. Any
-- code that teleported to one would have thrown the player into the sky.
function SanctumMap.ToWorld(v: Vector3): Vector3
	return ORIGIN + ROT * (v * SCALE)
end

-- Where a tunnel has to arrive: the far end of the boulevard, in world space.
SanctumMap.Entrance = SanctumMap.ToWorld(Vector3.new(0, 0, 184)) + Vector3.new(0, 2, 0)

-- Where the second way in arrives: partway along the boulevard, facing the
-- pyramid. The library stair comes down here; the headmaster's tunnel arrives
-- at the far west end, so the two doors do not open onto the same paving slab.
SanctumMap.Landing = SanctumMap.ToWorld(Vector3.new(17, 0, 87)) + Vector3.new(0, 1.5, 0)
SanctumMap.Scale = SCALE
SanctumMap.Origin = ORIGIN

local Config = {
	FoundingSeats = 100,
	Textures = {
		Parquet = "rbxassetid://117806376265747",
		Damask = "rbxassetid://79785225422126",
		Wainscot = "rbxassetid://95675620520590",
		Rug = "rbxassetid://78350443825536",
		Coffer = "rbxassetid://123203311167714",
		Geo1 = "rbxassetid://85762570200142",
		Geo2 = "rbxassetid://125084592316701",
		Geo3 = "rbxassetid://72182789931519",
	},
	Meshes = {
		Chandelier = 104671325601991,
		Wingback = 78958827728355,
		Candelabra = 113441049741419,
		Column = 139638345845432,
		Lamppost = 71751173797781,
		Gem = 137215970504108,
		Cloak = 87192563381111,
	},
}

local MARBLE = Color3.fromRGB(228, 222, 210)
local MARBLE_WHITE = Color3.fromRGB(240, 236, 228)
local GRANITE = Color3.fromRGB(24, 24, 28)
local GOLD = Color3.fromRGB(212, 175, 85)
local GOLD_BRIGHT = Color3.fromRGB(255, 208, 110)
local WALNUT = Color3.fromRGB(46, 32, 21)
local VELVET = Color3.fromRGB(74, 20, 24)
local WATER = Color3.fromRGB(70, 130, 160)

local PYR_CENTER_Z = -80
local PYR_TIERS = 15
local PYR_TIER_H = 9
local PYR_BASE_HALF = 140
local PYR_TOP_HALF = 12
local DOOR_Z = PYR_CENTER_Z + PYR_BASE_HALF - 4 -- north face
local HALL_CENTER = Vector3.new(0, 0, -80)
local HALL_R = 75
local HALL_H = 38

-- Every coordinate below is in the original estate's own space. This is the
-- only place that knows the estate is now smaller and underground: size is
-- scaled, position is scaled and then offset, and rotation is left alone.
local function place(cf: CFrame): CFrame
	local rotation = cf - cf.Position
	return CFrame.new(SanctumMap.ToWorld(cf.Position)) * ROT * rotation
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Size = p.Size * SCALE
	p.CFrame = place(p.CFrame)
	return p
end

local function tex(target: BasePart, face: Enum.NormalId, id: string, u: number, v: number)
	local t = Instance.new("Texture")
	t.Face = face
	t.Texture = id
	t.StudsPerTileU = u
	t.StudsPerTileV = v
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

local function _commas(n: number): string
	local out = tostring(math.floor(n))
	local formatted = out:reverse():gsub("(%d%d%d)", "%1,")
	local flipped = formatted:reverse():gsub("^,", "")
	return flipped
end

local function glowOrb(parent: Instance, pos: Vector3, scale: number, color: Color3): BasePart
	local core = part({
		Name = "GlowOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1) * scale,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.6 * scale
	light.Range = 16 * scale
	light.Shadows = false
	light.Parent = core
	return core
end

local function fillLight(parent: Instance, pos: Vector3, color: Color3, brightness: number, range: number)
	local anchor = part({
		Name = "FillLight",
		Size = Vector3.new(0.4, 0.4, 0.4),
		Transparency = 1,
		CanCollide = false,
		CFrame = CFrame.new(pos),
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = anchor
end

-- ---------------------------------------------------------------- meshes ---
type Style = { color: Color3, material: Enum.Material?, neon: boolean? }

local MESH_STYLES: { [number]: { Style } } = {
	[Config.Meshes.Chandelier] = {
		{ color = GOLD, material = Enum.Material.Metal },
		{ color = Color3.fromRGB(228, 220, 196) },
		{ color = GOLD_BRIGHT, material = Enum.Material.Neon, neon = true },
	},
	[Config.Meshes.Wingback] = {
		{ color = VELVET, material = Enum.Material.Fabric },
		{ color = WALNUT, material = Enum.Material.Wood },
	},
	[Config.Meshes.Candelabra] = {
		{ color = GOLD, material = Enum.Material.Metal },
		{ color = Color3.fromRGB(228, 220, 196) },
		{ color = GOLD_BRIGHT, material = Enum.Material.Neon, neon = true },
	},
	[Config.Meshes.Column] = {
		{ color = MARBLE_WHITE, material = Enum.Material.Marble },
	},
	[Config.Meshes.Lamppost] = {
		{ color = GOLD, material = Enum.Material.Metal },
		{ color = GOLD, material = Enum.Material.Metal },
		{ color = GOLD_BRIGHT, material = Enum.Material.Neon, neon = true },
	},
	[Config.Meshes.Gem] = {
		{ color = Color3.fromRGB(150, 190, 230), material = Enum.Material.Glass },
	},
}

local function loadMesh(assetId: number): Model?
	if assetId == 0 then
		return nil
	end
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not asset then
		warn("[MC] mesh " .. assetId .. " failed to load")
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
			if style.neon then
				local light = Instance.new("PointLight")
				light.Color = GOLD_BRIGHT
				light.Brightness = 1.2
				light.Range = 16
				light.Shadows = false
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
	-- meshes do not go through part(), so they take the estate's transform here
	clone:ScaleTo(scale * SCALE)
	clone:PivotTo(place(cf))
	clone.Parent = parent
	return clone
end

-- crystals: the estate's "planting" — translucent stones, nothing alive
local function crystalCluster(folder: Model, template: Model?, pos: Vector3, seed: number)
	local rng = Random.new(seed)
	for i = 1, rng:NextInteger(3, 5) do
		local scale = rng:NextNumber(1.2, 3.4)
		local tilt = CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5))
		local offset = Vector3.new(rng:NextNumber(-4, 4), scale * 0.8, rng:NextNumber(-4, 4))
		local placed = placeMesh(template, folder, "Crystal", CFrame.new(pos + offset) * tilt, scale)
		if placed then
			for _, p in placed:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = 0.15
					p.Reflectance = 0.12
					p.Material = Enum.Material.Ice
					p.Color = if i % 2 == 0 then Color3.fromRGB(150, 190, 230) else Color3.fromRGB(190, 170, 235)
				end
			end
		else
			local shard = part({
				Name = "CrystalShard",
				Size = Vector3.new(1.4, 3.4, 1.4) * scale * 0.6,
				CFrame = CFrame.new(pos + offset) * tilt,
				Color = Color3.fromRGB(150, 190, 230),
				Material = Enum.Material.Ice,
				Transparency = 0.15,
				CanCollide = false,
				Parent = folder,
			})
			local _ = shard
		end
	end
	glowOrb(folder, pos + Vector3.new(0, 0.6, 0), 0.6, Color3.fromRGB(170, 200, 255)).Transparency = 0.4
end

local function fountain(folder: Model, pos: Vector3, radius: number)
	part({
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE_WHITE,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, radius * 1.7, radius * 1.7),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = WATER,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		Reflectance = 0.3,
		CanCollide = false,
		Parent = folder,
	})
	part({
		Name = "FountainTier",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 0.8, radius * 0.8),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE_WHITE,
		Material = Enum.Material.Marble,
		CanCollide = false,
		Parent = folder,
	})
	local jet = part({
		Name = "FountainJet",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.4, 0.9, 0.9),
		CFrame = CFrame.new(pos + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 220, 240),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.3,
		CanCollide = false,
		Parent = folder,
	})
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(200, 230, 255)
	sparkle.Parent = jet
	fillLight(folder, pos + Vector3.new(0, 3, 0), Color3.fromRGB(190, 220, 255), 1.4, 26)
end

-- ---------------------------------------------------------------- estate ---
local function buildEstate(folder: Model, meshes: { [string]: Model? })
	part({
		Name = "Grounds",
		Size = Vector3.new(500, 2, 500),
		CFrame = CFrame.new(0, -1, 20),
		Color = GRANITE,
		Material = Enum.Material.Granite,
		Parent = folder,
	})

	-- the boulevard: marble walkways flanking a long reflecting pool
	local zNear, zFar = DOOR_Z + 10, 184
	local mid = (zNear + zFar) / 2
	local length = zFar - zNear
	part({
		Name = "BoulevardSlab",
		Size = Vector3.new(44, 0.6, length),
		CFrame = CFrame.new(0, 0.1, mid),
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	part({
		Name = "PoolRim",
		Size = Vector3.new(12, 1.1, length - 18),
		CFrame = CFrame.new(0, 0.35, mid),
		Color = MARBLE_WHITE,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	part({
		Name = "ReflectingPool",
		Size = Vector3.new(10, 0.7, length - 20),
		CFrame = CFrame.new(0, 0.5, mid),
		Color = WATER,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.28,
		Reflectance = 0.42,
		CanCollide = true,
		Parent = folder,
	})
	-- gold seams edging the walkways
	for _, x in { -22, 22 } do
		part({
			Name = "GoldSeam",
			Size = Vector3.new(0.5, 0.55, length),
			CFrame = CFrame.new(x, 0.08, mid),
			Color = GOLD_BRIGHT,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = folder,
		})
	end

	-- colonnades and gold lampposts down both sides
	for z = zNear + 8, zFar - 8, 14 do
		for _, x in { -17, 17 } do
			placeMesh(meshes.column, folder, "BoulevardColumn", CFrame.new(x, 0, z), 1.15)
		end
		for _, x in { -27, 27 } do
			placeMesh(meshes.lamppost, folder, "EstateLamp", CFrame.new(x, 4.7, z + 7), 1.0)
		end
	end

	-- fountains flanking the plaza before the doors
	fountain(folder, Vector3.new(-32, 0, DOOR_Z + 22), 7)
	fountain(folder, Vector3.new(32, 0, DOOR_Z + 22), 7)

	-- four gold-tipped obelisks marking the boulevard corners
	for _, spot in { Vector3.new(-40, 0, zFar - 6), Vector3.new(40, 0, zFar - 6), Vector3.new(-46, 0, DOOR_Z + 40), Vector3.new(46, 0, DOOR_Z + 40) } do
		part({
			Name = "Obelisk",
			Size = Vector3.new(3.4, 20, 3.4),
			CFrame = CFrame.new(spot + Vector3.new(0, 10, 0)),
			Color = MARBLE_WHITE,
			Material = Enum.Material.Marble,
			Parent = folder,
		})
		part({
			Name = "ObeliskTip",
			Size = Vector3.new(2.2, 2.6, 2.2),
			CFrame = CFrame.new(spot + Vector3.new(0, 21.3, 0)) * CFrame.Angles(0, math.rad(45), 0),
			Color = GOLD_BRIGHT,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		fillLight(folder, spot + Vector3.new(0, 21, 0), GOLD_BRIGHT, 1.4, 30)
	end

	-- crystal gardens ringing the estate (the halal planting)
	local rng = Random.new(7)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local d = rng:NextNumber(125, 215)
		local x, z = math.sin(a) * d, math.cos(a) * d + 10
		if math.abs(x) > 30 or z > 150 or z < PYR_CENTER_Z - PYR_BASE_HALF - 10 then
			crystalCluster(folder, meshes.gem, Vector3.new(x, 0, z), i * 13 + 5)
		end
	end
end

-- ---------------------------------------------------------------- pyramid ---
local function buildPyramid(folder: Model): (BasePart, BasePart, BasePart)
	local thick = 8
	for t = 0, PYR_TIERS - 1 do
		local half = PYR_BASE_HALF - t * (PYR_BASE_HALF - PYR_TOP_HALF) / (PYR_TIERS - 1)
		local y = t * PYR_TIER_H + PYR_TIER_H / 2
		local zc = PYR_CENTER_Z
		local function slab(name: string, size: Vector3, cf: CFrame)
			part({ Name = name, Size = size, CFrame = cf, Color = MARBLE, Material = Enum.Material.Marble, Parent = folder })
		end
		if t <= 1 then
			local gap = 14
			local segW = half - gap
			slab("PyrN", Vector3.new(segW, PYR_TIER_H, thick), CFrame.new(-(gap + segW / 2), y, zc + half - thick / 2))
			slab("PyrN", Vector3.new(segW, PYR_TIER_H, thick), CFrame.new(gap + segW / 2, y, zc + half - thick / 2))
		else
			slab("PyrN", Vector3.new(half * 2, PYR_TIER_H, thick), CFrame.new(0, y, zc + half - thick / 2))
		end
		slab("PyrS", Vector3.new(half * 2, PYR_TIER_H, thick), CFrame.new(0, y, zc - half + thick / 2))
		slab("PyrE", Vector3.new(thick, PYR_TIER_H, half * 2 - thick * 2), CFrame.new(half - thick / 2, y, zc))
		slab("PyrW", Vector3.new(thick, PYR_TIER_H, half * 2 - thick * 2), CFrame.new(-(half - thick / 2), y, zc))
		-- one restrained gold trim at the base tier only — the LED-strip wall
		-- of lines read as glare, not luxury
		if t == 0 then
			part({
				Name = "TierTrim",
				Size = Vector3.new(half * 2, 0.4, 0.4),
				CFrame = CFrame.new(0, y + PYR_TIER_H / 2 - 0.2, zc + half - 0.2),
				Color = GOLD,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = folder,
			})
		end
	end

	-- the capstone burns gold, with a light column rising off it
	local capY = PYR_TIERS * PYR_TIER_H
	local capstone = part({
		Name = "Capstone",
		Size = Vector3.new(PYR_TOP_HALF * 2, 6, PYR_TOP_HALF * 2),
		CFrame = CFrame.new(0, capY + 3, PYR_CENTER_Z),
		Color = GOLD_BRIGHT,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	local capLight = Instance.new("PointLight")
	capLight.Color = GOLD_BRIGHT
	capLight.Brightness = 4
	capLight.Range = 100
	capLight.Parent = capstone
	part({
		Name = "CapBeam",
		Size = Vector3.new(1.6, 90, 1.6),
		CFrame = CFrame.new(0, capY + 48, PYR_CENTER_Z),
		Color = GOLD_BRIGHT,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		Parent = folder,
	})

	-- the marquee over the entrance
	local marquee = part({
		Name = "Marquee",
		Size = Vector3.new(46, 7.5, 0.8),
		CFrame = CFrame.new(0, 28, PYR_CENTER_Z + PYR_BASE_HALF - 12),
		Color = GRANITE,
		Material = Enum.Material.Slate,
		CanCollide = false,
		Parent = folder,
	})
	signText(marquee, "ROBES", GOLD_BRIGHT, Enum.NormalId.Front)
	local sub = part({
		Name = "MarqueeSub",
		Size = Vector3.new(34, 2.6, 0.6),
		CFrame = CFrame.new(0, 23, PYR_CENTER_Z + PYR_BASE_HALF - 12),
		Color = GRANITE,
		Material = Enum.Material.Slate,
		CanCollide = false,
		Parent = folder,
	})
	signText(sub, "100 ROBES · EVER", Color3.fromRGB(210, 205, 195), Enum.NormalId.Front, 42)

	-- geometric panels flanking the doors
	local faceZ = PYR_CENTER_Z + PYR_BASE_HALF + 0.4
	local geos = { Config.Textures.Geo1, Config.Textures.Geo2, Config.Textures.Geo3 }
	for i, x in { -34, 34, -46 } do
		local p = part({
			Name = "FacePanel",
			Size = Vector3.new(8, 10, 0.5),
			CFrame = CFrame.new(x, 7, faceZ),
			Color = GRANITE,
			Material = Enum.Material.Slate,
			CanCollide = false,
			Parent = folder,
		})
		decal(p, Enum.NormalId.Front, geos[i])
	end

	-- The grand doors: tall gold, and a gate part that owns the prompt.
	--
	-- Built STANDING OPEN, swung back against the face of the pyramid. In the
	-- game these came from they were shut until you bought a seat, and nothing
	-- carried that check across -- so they were simply solid, and the reward at
	-- the bottom of a hundred and ten steps was a sealed building you could
	-- walk around and look at. The lock on this place is the bookshelf and the
	-- four digits; past those, the doors are open.
	local doorL = part({
		Name = "DoorL",
		Size = Vector3.new(7, 18, 1.2),
		CFrame = CFrame.new(-7, 9, DOOR_Z - 3) * CFrame.Angles(0, math.rad(-78), 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = folder,
	})
	local doorR = part({
		Name = "DoorR",
		Size = Vector3.new(7, 18, 1.2),
		CFrame = CFrame.new(7, 9, DOOR_Z - 3) * CFrame.Angles(0, math.rad(78), 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = folder,
	})
	decal(doorL, Enum.NormalId.Front, Config.Textures.Geo1)
	decal(doorR, Enum.NormalId.Front, Config.Textures.Geo1)
	local gate = part({
		Name = "DoorGate",
		Size = Vector3.new(15, 18, 0.4),
		CFrame = CFrame.new(0, 9, DOOR_Z + 1.2),
		Transparency = 1,
		CanCollide = false,
		Parent = folder,
	})
	-- the price, posted at the door like the world's most exclusive menu
	local pricePlinth = part({
		Name = "PricePlinth",
		Size = Vector3.new(3, 4.2, 3),
		CFrame = CFrame.new(13, 2.1, DOOR_Z + 10),
		Color = MARBLE_WHITE,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	local priceBoard = part({
		Name = "PriceBoard",
		Size = Vector3.new(5.4, 3.4, 0.5),
		CFrame = CFrame.new(13, 6, DOOR_Z + 10) * CFrame.Angles(math.rad(-14), 0, 0),
		Color = GRANITE,
		Material = Enum.Material.Slate,
		Parent = folder,
	})
	local _ = pricePlinth
	local priceLabel = signText(priceBoard, "THE ROBE\nNOT FOR SALE\nPRINCIPAL ONLY", GOLD_BRIGHT, Enum.NormalId.Front, 34)

	-- the roster this used to count lives in another game; down here it is a
	-- plaque, and the number on it is a joke only the principal is in on
	local _ = priceLabel

	return doorL, doorR, gate
end

-- ------------------------------------------------------- chamber builder ---
export type Gate = { tier: string, door: BasePart, landing: Vector3 }

type ChamberSpec = {
	name: string,
	y: number,
	r: number,
	h: number,
	floorColor: Color3,
	wallColor: Color3,
	accent: Color3,
}

local function buildChamber(folder: Model, meshes: { [string]: Model? }, spec: ChamberSpec): (Vector3, BasePart)
	local cx, cz = 0, PYR_CENTER_Z
	local segW = 2 * spec.r * math.tan(math.pi / 8) + 2

	local floor = part({
		Name = spec.name .. "Floor",
		Size = Vector3.new(spec.r * 2 + 6, 1, spec.r * 2 + 6),
		CFrame = CFrame.new(cx, spec.y - 0.5, cz),
		Color = spec.floorColor,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	tex(floor, Enum.NormalId.Top, Config.Textures.Parquet, 10, 10)
	local ceiling = part({
		Name = spec.name .. "Ceiling",
		Size = Vector3.new(spec.r * 2 + 6, 1, spec.r * 2 + 6),
		CFrame = CFrame.new(cx, spec.y + spec.h + 0.5, cz),
		Color = Color3.fromRGB(24, 18, 13),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	tex(ceiling, Enum.NormalId.Bottom, Config.Textures.Coffer, 10, 10)

	local geos = { Config.Textures.Geo1, Config.Textures.Geo2, Config.Textures.Geo3 }
	for i = 1, 8 do
		local a = (i - 1) / 8 * math.pi * 2
		local nx, nz = math.sin(a), math.cos(a)
		local pos = Vector3.new(cx + nx * spec.r, spec.y, cz + nz * spec.r)
		local cf = CFrame.lookAt(pos, pos - Vector3.new(nx, 0, nz))
		part({
			Name = spec.name .. "Wall",
			Size = Vector3.new(segW, spec.h, 1.2),
			CFrame = cf * CFrame.new(0, spec.h / 2, 0),
			Color = spec.wallColor,
			Material = Enum.Material.Marble,
			Parent = folder,
		})
		part({
			Name = spec.name .. "Rail",
			Size = Vector3.new(segW, 0.4, 1.5),
			CFrame = cf * CFrame.new(0, spec.h * 0.4, 0),
			Color = spec.accent,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})
		if i % 2 == 0 then
			local panel = part({
				Name = spec.name .. "Panel",
				Size = Vector3.new(4.6, 5.6, 0.4),
				CFrame = cf * CFrame.new(0, spec.h * 0.55, -0.9),
				Color = GRANITE,
				Material = Enum.Material.Slate,
				CanCollide = false,
				Parent = folder,
			})
			decal(panel, Enum.NormalId.Back, geos[(i // 2 - 1) % 3 + 1])
		end
	end

	placeMesh(meshes.chandelier, folder, spec.name .. "Chandelier", CFrame.new(cx, spec.y + spec.h - 7, cz), math.max(1.2, spec.r / 12))
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local pos = Vector3.new(cx + math.sin(a) * (spec.r - 6), spec.y, cz + math.cos(a) * (spec.r - 6))
		placeMesh(meshes.wingback, folder, spec.name .. "Chair", CFrame.lookAt(pos, Vector3.new(cx, spec.y, cz)) * CFrame.Angles(0, math.pi, 0), 1.05)
		local seat = Instance.new("Seat")
		seat.Size = Vector3.new(3, 0.4, 3)
		seat.CFrame = CFrame.lookAt(pos, Vector3.new(cx, spec.y, cz)) * CFrame.new(0, 1.6, 0)
		seat.Anchored = true
		seat.Transparency = 1
		seat.Parent = folder
	end
	fillLight(folder, Vector3.new(cx, spec.y + spec.h - 4, cz), GOLD_BRIGHT, 2.2, spec.r * 3)

	-- descent pad
	local pad = part({
		Name = spec.name .. "Descent",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 5, 5),
		CFrame = CFrame.new(cx, spec.y + 0.2, cz + spec.r - 4) * CFrame.Angles(0, 0, math.rad(90)),
		Color = spec.accent,
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	return SanctumMap.ToWorld(Vector3.new(cx, spec.y + 3, cz - spec.r + 6)), pad
end

-- ------------------------------------------------------------ grand hall ---
local function buildGrandHall(folder: Model, meshes: { [string]: Model? }): (BasePart, BasePart)
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

	local registryWall: BasePart? = nil
	local goldGate: BasePart? = nil
	local geos = { Config.Textures.Geo1, Config.Textures.Geo2, Config.Textures.Geo3 }

	for i = 1, 8 do
		local a = (i - 1) / 8 * math.pi * 2
		local nx, nz = math.sin(a), math.cos(a)
		local pos = Vector3.new(cx + nx * HALL_R, 0, cz + nz * HALL_R)
		local cf = CFrame.lookAt(pos, pos - Vector3.new(nx, 0, nz))
		local isEntry = (i == 1)

		if not isEntry then
			local lower = part({
				Name = "HallWainscot",
				Size = Vector3.new(segW, 13, 1.2),
				CFrame = cf * CFrame.new(0, 6.5, 0),
				Color = WALNUT,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			tex(lower, Enum.NormalId.Back, Config.Textures.Wainscot, 12, 9)
			local upper = part({
				Name = "HallDamask",
				Size = Vector3.new(segW, HALL_H - 13, 1.2),
				CFrame = cf * CFrame.new(0, 13 + (HALL_H - 13) / 2, 0),
				Color = Color3.fromRGB(48, 30, 34),
				Material = Enum.Material.Fabric,
				Parent = folder,
			})
			tex(upper, Enum.NormalId.Back, Config.Textures.Damask, 12, 12)
			part({
				Name = "GiltRail",
				Size = Vector3.new(segW, 0.5, 1.6),
				CFrame = cf * CFrame.new(0, 13.2, 0),
				Color = GOLD,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = folder,
			})
		else
			for _, side in { -1, 1 } do
				part({
					Name = "EntryJamb",
					Size = Vector3.new((segW - 18) / 2, HALL_H, 1.2),
					CFrame = cf * CFrame.new(side * (segW / 2 - (segW - 18) / 4), HALL_H / 2, 0),
					Color = WALNUT,
					Material = Enum.Material.Wood,
					Parent = folder,
				})
			end
			part({
				Name = "EntryLintel",
				Size = Vector3.new(18, HALL_H - 19, 1.2),
				CFrame = cf * CFrame.new(0, 19 + (HALL_H - 19) / 2, 0),
				Color = WALNUT,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end

		local va = (i - 1) / 8 * math.pi * 2 + math.pi / 8
		placeMesh(meshes.column, folder, "HallColumn",
			CFrame.new(cx + math.sin(va) * (HALL_R - 2.5), 0, cz + math.cos(va) * (HALL_R - 2.5)), HALL_H / 11.7)
		if not isEntry then
			placeMesh(meshes.candelabra, folder, "HallCandelabra", cf * CFrame.new(-20, 0, 4), 1.6)
			placeMesh(meshes.candelabra, folder, "HallCandelabra", cf * CFrame.new(20, 0, 4), 1.6)
		end

		if i == 5 then
			-- the golden lift to the GOLD chamber, opposite the entry
			goldGate = part({
				Name = "Gate_GOLD",
				Size = Vector3.new(14, 20, 0.8),
				CFrame = cf * CFrame.new(0, 10, -1),
				Color = GOLD,
				Material = Enum.Material.Metal,
				Parent = folder,
			})
			decal(goldGate :: BasePart, Enum.NormalId.Back, Config.Textures.Geo2)
			local plaque = part({
				Name = "GatePlaque",
				Size = Vector3.new(12, 1.9, 0.3),
				CFrame = cf * CFrame.new(0, 21.6, -1.2),
				Color = GRANITE,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = folder,
			})
			signText(plaque, "THE GOLD CHAMBER", GOLD_BRIGHT, Enum.NormalId.Back, 44)
		elseif i == 3 then
			-- THE FOUNDING 100 registry wall
			registryWall = part({
				Name = "RegistryWall",
				Size = Vector3.new(30, 18, 0.6),
				CFrame = cf * CFrame.new(0, 11, -1),
				Color = GRANITE,
				Material = Enum.Material.Slate,
				Parent = folder,
			})
			part({
				Name = "RegistryFrame",
				Size = Vector3.new(31, 19, 0.4),
				CFrame = cf * CFrame.new(0, 11, -0.7),
				Color = GOLD,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = folder,
			})
			signText(registryWall :: BasePart, "THE FOUNDING 100", GOLD_BRIGHT, Enum.NormalId.Back, 72)
		elseif i == 7 then
			-- fireplace
			part({
				Name = "Fireplace",
				Size = Vector3.new(26, 16, 2),
				CFrame = cf * CFrame.new(0, 8, -1.2),
				Color = GRANITE,
				Material = Enum.Material.Slate,
				Parent = folder,
			})
			part({
				Name = "FireplaceMouth",
				Size = Vector3.new(16, 10, 1.4),
				CFrame = cf * CFrame.new(0, 5, -1.9),
				Color = Color3.fromRGB(10, 9, 12),
				Material = Enum.Material.Slate,
				CanCollide = false,
				Parent = folder,
			})
			part({
				Name = "Mantel",
				Size = Vector3.new(30, 1.4, 4),
				CFrame = cf * CFrame.new(0, 16.6, -1.2),
				Color = WALNUT,
				Material = Enum.Material.Wood,
				CanCollide = false,
				Parent = folder,
			})
			local ember = glowOrb(folder, (cf * CFrame.new(0, 3, -1.9)).Position, 2.6, Color3.fromRGB(255, 150, 60))
			local fire = Instance.new("Fire")
			fire.Size = 12
			fire.Heat = 10
			fire.Parent = ember
		elseif not isEntry then
			for _, ox in { -16, 16 } do
				local p = part({
					Name = "HallGeoPanel",
					Size = Vector3.new(9, 11.5, 0.5),
					CFrame = cf * CFrame.new(ox, 21, -1.3),
					Color = GRANITE,
					Material = Enum.Material.Slate,
					CanCollide = false,
					Parent = folder,
				})
				decal(p, Enum.NormalId.Back, geos[(i + (ox > 0 and 1 or 0)) % 3 + 1])
			end
		end
	end

	for _, spot in { Vector3.new(-32, 0, 0), Vector3.new(32, 0, 0), Vector3.new(0, 0, -32), Vector3.new(0, 0, 32) } do
		placeMesh(meshes.chandelier, folder, "GrandChandelier", CFrame.new(cx + spot.X, HALL_H - 11, cz + spot.Z), 3.6)
	end

	-- the central fountain — marble and gold, lit from within
	part({
		Name = "HallFountainDais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 30, 30),
		CFrame = CFrame.new(cx, 0.7, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = MARBLE_WHITE,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	fountain(folder, Vector3.new(cx, 1.5, cz), 10)
	part({
		Name = "FountainCrown",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 3.4, 3.4),
		CFrame = CFrame.new(cx, 10.6, cz),
		Color = GOLD_BRIGHT,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})

	-- the circle of wingbacks around the fountain
	local seatIndex = 0
	for _, ring in { { r = 24, n = 12 }, { r = 44, n = 16 } } do
		for i = 1, ring.n do
			seatIndex += 1
			local a = (i - 1) / ring.n * math.pi * 2 + (ring.r > 30 and math.pi / ring.n or 0)
			local pos = Vector3.new(cx + math.sin(a) * ring.r, 0, cz + math.cos(a) * ring.r)
			local facing = CFrame.lookAt(pos, Vector3.new(cx, 0, cz))
			placeMesh(meshes.wingback, folder, "CircleChair", facing * CFrame.Angles(0, math.pi, 0), 1.05)
			local seat = Instance.new("Seat")
			seat.Name = "CircleSeat" .. seatIndex
			seat.Size = Vector3.new(3, 0.4, 3)
			seat.CFrame = facing * CFrame.new(0, 1.6, 0)
			seat.Anchored = true
			seat.Transparency = 1
			seat.Parent = folder
		end
	end

	for _, spot in { Vector3.new(-32, 0, 0), Vector3.new(32, 0, 0), Vector3.new(0, 0, -32), Vector3.new(0, 0, 32) } do
		fillLight(folder, Vector3.new(cx + spot.X, HALL_H - 11, cz + spot.Z), GOLD_BRIGHT, 1.8, 55)
	end
	fillLight(folder, Vector3.new(cx, 20, cz), Color3.fromRGB(215, 225, 255), 1.0, 70)

	return registryWall :: BasePart, goldGate :: BasePart
end

-- the atrium corridor from the doors to the hall
local function buildAtrium(folder: Model, meshes: { [string]: Model? })
	local zStart, zEnd = DOOR_Z, HALL_CENTER.Z + HALL_R + 2
	local length = zStart - zEnd
	local mid = (zStart + zEnd) / 2

	local floor = part({
		Name = "AtriumFloor",
		Size = Vector3.new(20, 1, length),
		CFrame = CFrame.new(0, -0.5, mid),
		Color = MARBLE,
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	local _ = floor
	part({
		Name = "AtriumCarpet",
		Size = Vector3.new(9, 0.15, length),
		CFrame = CFrame.new(0, 0.08, mid),
		Color = Color3.fromRGB(122, 28, 38),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = folder,
	})
	local ceiling = part({
		Name = "AtriumCeiling",
		Size = Vector3.new(20, 1, length),
		CFrame = CFrame.new(0, 18.5, mid),
		Color = Color3.fromRGB(26, 20, 15),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	tex(ceiling, Enum.NormalId.Bottom, Config.Textures.Coffer, 10, 10)
	local geos = { Config.Textures.Geo1, Config.Textures.Geo2, Config.Textures.Geo3 }
	for _, side in { -1, 1 } do
		local wall = part({
			Name = "AtriumWall",
			Size = Vector3.new(1, 19, length),
			CFrame = CFrame.new(side * 10.5, 9, mid),
			Color = MARBLE,
			Material = Enum.Material.Marble,
			Parent = folder,
		})
		local face = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
		tex(wall, face, Config.Textures.Wainscot, 12, 13)
	end
	local n = math.floor(length / 12)
	for i = 0, n do
		local z = zStart - 8 - i * 12
		if z <= zEnd + 4 then
			break
		end
		local side = (i % 2 == 0) and -1 or 1
		placeMesh(meshes.candelabra, folder, "AtriumCandelabra", CFrame.new(side * 8, 0, z), 1.3)
		local p = part({
			Name = "AtriumGeoPanel",
			Size = Vector3.new(0.4, 8, 6.4),
			CFrame = CFrame.new(-side * 10.2, 8.4, z),
			Color = GRANITE,
			Material = Enum.Material.Slate,
			CanCollide = false,
			Parent = folder,
		})
		decal(p, side < 0 and Enum.NormalId.Left or Enum.NormalId.Right, geos[(i % 3) + 1])
		fillLight(folder, Vector3.new(0, 13, z), GOLD_BRIGHT, 1.1, 30)
	end
end

-- ------------------------------------------------------------------ build ---
export type Map = {
	folder: Model,
	doorL: BasePart,
	doorR: BasePart,
	memberGate: BasePart,
	gates: { Gate },
	descents: { BasePart },
	registryWall: BasePart?,
	hallCenter: Vector3,
	hallPoint: Vector3,
}

function SanctumMap.Build(): Map
	-- a Persistent model: the estate streams in once at join and never pops
	-- out as you move (the join is a beat slower; movement is rock solid)
	local folder = Instance.new("Model")
	folder.Name = "Sanctum"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Parent = workspace

	-- no SpawnLocation: this is not somewhere you respawn into, it is
	-- somewhere you walk down to

	local meshes = {
		column = loadMesh(Config.Meshes.Column),
		chandelier = loadMesh(Config.Meshes.Chandelier),
		candelabra = loadMesh(Config.Meshes.Candelabra),
		wingback = loadMesh(Config.Meshes.Wingback),
		lamppost = loadMesh(Config.Meshes.Lamppost),
		gem = loadMesh(Config.Meshes.Gem),
		cloak = loadMesh(Config.Meshes.Cloak),
	}

	buildEstate(folder, meshes)
	local doorL, doorR, doorGate = buildPyramid(folder)
	buildAtrium(folder, meshes)
	local registryWall, goldGate = buildGrandHall(folder, meshes)

	-- ascending chambers
	local gates: { Gate } = {}
	local descents: { BasePart } = {}

	local goldLanding, goldPad = buildChamber(folder, meshes, {
		name = "Gold", y = 52, r = 40, h = 16,
		floorColor = Color3.fromRGB(96, 78, 40),
		wallColor = Color3.fromRGB(210, 190, 140),
		accent = GOLD,
	})
	table.insert(gates, { tier = "GOLD", door = goldGate, landing = goldLanding })
	table.insert(descents, goldPad)

	local platLanding, platPad = buildChamber(folder, meshes, {
		name = "Platinum", y = 78, r = 28, h = 14,
		floorColor = Color3.fromRGB(200, 204, 212),
		wallColor = MARBLE_WHITE,
		accent = Color3.fromRGB(226, 230, 236),
	})
	table.insert(descents, platPad)

	local blackLanding, blackPad = buildChamber(folder, meshes, {
		name = "Black", y = 100, r = 18, h = 12,
		floorColor = Color3.fromRGB(18, 17, 21),
		wallColor = Color3.fromRGB(28, 27, 32),
		accent = GOLD,
	})
	table.insert(descents, blackPad)

	local crownLanding, crownPad = buildChamber(folder, meshes, {
		name = "Crown", y = 118, r = 11, h = 9,
		floorColor = Color3.fromRGB(120, 96, 44),
		wallColor = Color3.fromRGB(160, 130, 62),
		accent = GOLD_BRIGHT,
	})
	table.insert(descents, crownPad)

	-- gates within chambers to the next chamber up
	local function chamberGate(name: string, tier: string, y: number, r: number, landing: Vector3)
		local cz = PYR_CENTER_Z
		local door = part({
			Name = "Gate_" .. tier,
			Size = Vector3.new(6, 9, 0.8),
			CFrame = CFrame.new(0, y + 4.5, cz - r + 1.4),
			Color = GOLD,
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		decal(door, Enum.NormalId.Front, Config.Textures.Geo2)
		signText(door, tier, GRANITE, Enum.NormalId.Front, 50)
		table.insert(gates, { tier = tier, door = door :: BasePart, landing = landing })
		local _ = name
	end
	chamberGate("Gold", "PLATINUM", 52, 40, platLanding)
	chamberGate("Platinum", "BLACK", 78, 28, blackLanding)
	chamberGate("Black", "CROWN", 100, 18, crownLanding)

	-- the crown chamber gets its jewel
	local crownJewel = placeMesh(meshes.gem, folder, "CrownJewel", CFrame.new(0, 122.5, PYR_CENTER_Z), 3.0)
	if crownJewel then
		for _, p in crownJewel:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = GOLD_BRIGHT
				p.Material = Enum.Material.Glass
				p.Transparency = 0.08
				p.Reflectance = 0.4
			end
		end
		fillLight(folder, Vector3.new(0, 123, PYR_CENTER_Z), GOLD_BRIGHT, 2.6, 34)
	end

	-- Every gate down here is decoration. The lock on this place is the
	-- bookshelf and the four digits, not a membership roster.
	for _, gate in gates do
		gate.door.CanCollide = false
		gate.door.Transparency = 0.55
	end
	if doorGate then
		doorGate.CanCollide = false
		doorGate.Transparency = 0.55
	end

	return {
		folder = folder,
		doorL = doorL,
		doorR = doorR,
		memberGate = doorGate,
		gates = gates,
		descents = descents,
		registryWall = registryWall,
		hallCenter = SanctumMap.ToWorld(HALL_CENTER),
		hallPoint = SanctumMap.ToWorld(Vector3.new(HALL_CENTER.X, 3, HALL_CENTER.Z + 58)),
	}
end

return SanctumMap
