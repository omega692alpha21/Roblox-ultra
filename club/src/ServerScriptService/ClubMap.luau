--!strict
-- The clubhouse: a public reception showroom anyone can walk, and the private
-- club behind the grand doors. Built to feel expensive, not enormous.

local ClubMap = {}

local MARBLE = Color3.fromRGB(232, 228, 220)
local MARBLE_DARK = Color3.fromRGB(52, 50, 54)
local WALNUT = Color3.fromRGB(62, 44, 34)
local GOLD = Color3.fromRGB(212, 175, 85)
local VELVET = Color3.fromRGB(122, 28, 38)
local CREAM = Color3.fromRGB(240, 234, 222)

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

local function chandelier(parent: Instance, pos: Vector3)
	local core = part({ Name = "ChandelierCore", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(pos), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local bulb = part({
			Name = "ChandelierBulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 1.8, -0.5, math.sin(a) * 1.8)),
			Color = Color3.fromRGB(255, 236, 190),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local _ = bulb
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 226, 170)
	light.Brightness = 1.6
	light.Range = 26
	light.Parent = core
	part({ Name = "ChandelierRod", Size = Vector3.new(0.18, 3, 0.18), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
end

local function loungeSeat(parent: Instance, cf: CFrame, color: Color3)
	part({ Name = "SeatBase", Size = Vector3.new(3.2, 1.1, 3), CFrame = cf * CFrame.new(0, 0.55, 0), Color = color, Material = Enum.Material.Fabric, Parent = parent })
	part({ Name = "SeatBack", Size = Vector3.new(3.2, 2, 0.8), CFrame = cf * CFrame.new(0, 1.9, 1.15), Color = color, Material = Enum.Material.Fabric, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "SeatArm", Size = Vector3.new(0.6, 1.7, 3), CFrame = cf * CFrame.new(side * 1.85, 0.85, 0), Color = color, Material = Enum.Material.Fabric, Parent = parent })
	end
end

export type Map = {
	folder: Folder,
	doorGate: BasePart,
	counterLabel: TextLabel,
	receptionSpawn: Vector3,
	clubInterior: Vector3,
}

function ClubMap.Build(): Map
	local folder = Instance.new("Folder")
	folder.Name = "MillionsClub"
	folder.Parent = workspace

	-- night-city ground plane
	part({ Name = "Plaza", Size = Vector3.new(220, 1, 220), CFrame = CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.Slate, Parent = folder })

	-- ===== reception (public showroom), z 20..60 =====
	part({ Name = "ReceptionFloor", Size = Vector3.new(60, 1, 40), CFrame = CFrame.new(0, 0.02, 40), Color = MARBLE, Material = Enum.Material.Marble, Parent = folder })
	-- checker inlay
	for i = 0, 4 do
		for j = 0, 2 do
			part({ Name = "FloorInlay", Size = Vector3.new(5.5, 0.06, 5.5), CFrame = CFrame.new(-22 + i * 11, 0.55, 29 + j * 11), Color = MARBLE_DARK, Material = Enum.Material.Marble, Parent = folder })
		end
	end
	-- walls
	for _, spec in {
		{ size = Vector3.new(60, 16, 1.5), cf = CFrame.new(0, 8, 60) },
		{ size = Vector3.new(1.5, 16, 40), cf = CFrame.new(-30, 8, 40) },
		{ size = Vector3.new(1.5, 16, 40), cf = CFrame.new(30, 8, 40) },
	} do
		part({ Name = "ReceptionWall", Size = spec.size, CFrame = spec.cf, Color = WALNUT, Material = Enum.Material.WoodPlanks, Parent = folder })
	end
	-- gold wall trim
	for _, y in { 1.2, 14.5 } do
		part({ Name = "GoldTrim", Size = Vector3.new(60, 0.5, 0.4), CFrame = CFrame.new(0, y, 59.2), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
	end
	part({ Name = "ReceptionCeiling", Size = Vector3.new(60, 1, 40), CFrame = CFrame.new(0, 16.5, 40), Color = Color3.fromRGB(24, 22, 26), Parent = folder })
	chandelier(folder, Vector3.new(0, 13.5, 40))
	chandelier(folder, Vector3.new(-18, 13.5, 40))
	chandelier(folder, Vector3.new(18, 13.5, 40))

	-- entrance facade + name
	local marquee = part({ Name = "Marquee", Size = Vector3.new(34, 6, 1.2), CFrame = CFrame.new(0, 19.5, 60), Color = Color3.fromRGB(16, 15, 18), Parent = folder })
	signText(marquee, "MILLIONS CLUB", GOLD, Enum.NormalId.Back)
	signText(marquee, "MILLIONS CLUB", GOLD, Enum.NormalId.Front)

	-- membership counter board
	local counterBoard = part({ Name = "CounterBoard", Size = Vector3.new(16, 9, 1), CFrame = CFrame.new(-20, 7, 59), Color = Color3.fromRGB(14, 13, 16), Parent = folder })
	signText(counterBoard, "MEMBERSHIPS", CREAM, Enum.NormalId.Back)
	local counterLabelHolder = part({ Name = "CounterNumber", Size = Vector3.new(16, 5, 1), CFrame = CFrame.new(-20, 3, 59), Color = Color3.fromRGB(14, 13, 16), Parent = folder })
	local counterLabel = signText(counterLabelHolder, "0 / 100", GOLD, Enum.NormalId.Back)

	-- rules board
	local rules = part({ Name = "RulesBoard", Size = Vector3.new(16, 12, 1), CFrame = CFrame.new(20, 7, 59), Color = Color3.fromRGB(14, 13, 16), Parent = folder })
	signText(rules, "ONE MEMBERSHIP.\n100 MEMBERS. EVER.\n\nNO TIERS.\nNO SECOND CHANCES.", CREAM, Enum.NormalId.Back, 34)

	-- velvet ropes leading to the doors
	for _, x in { -6, 6 } do
		for i = 0, 3 do
			local post = part({ Name = "RopePost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 0.5, 0.5), CFrame = CFrame.new(x, 1.7, 26 + i * 8) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
			local _ = post
			if i < 3 then
				part({ Name = "Rope", Size = Vector3.new(0.3, 0.3, 7.2), CFrame = CFrame.new(x, 2.9, 30 + i * 8), Color = VELVET, Material = Enum.Material.Fabric, Parent = folder })
			end
		end
	end
	-- red carpet
	part({ Name = "RedCarpet", Size = Vector3.new(9, 0.12, 40), CFrame = CFrame.new(0, 0.58, 40), Color = VELVET, Material = Enum.Material.Fabric, Parent = folder })

	-- ===== the grand doors + gate (members only beyond) =====
	local doorFrame = part({ Name = "DoorFrame", Size = Vector3.new(14, 14, 2), CFrame = CFrame.new(0, 7, 20), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
	local _ = doorFrame
	for _, side in { -1, 1 } do
		part({ Name = "GrandDoor", Size = Vector3.new(5.4, 12, 0.8), CFrame = CFrame.new(side * 3, 6, 20), Color = WALNUT, Material = Enum.Material.Wood, Parent = folder })
		part({ Name = "DoorHandle", Size = Vector3.new(0.3, 1.6, 0.3), CFrame = CFrame.new(side * 0.8, 6, 19.4), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
	end
	local doorGate = part({ Name = "DoorGate", Size = Vector3.new(12, 12, 0.5), CFrame = CFrame.new(0, 6, 20), Transparency = 1, CanCollide = true, Parent = folder })
	-- reception outer walls flanking the door so the club is sealed
	for _, side in { -1, 1 } do
		part({ Name = "FrontWall", Size = Vector3.new(23, 16, 1.5), CFrame = CFrame.new(side * 18.5, 8, 20), Color = WALNUT, Material = Enum.Material.WoodPlanks, Parent = folder })
	end

	-- ===== private club (z -40..20) =====
	part({ Name = "ClubFloor", Size = Vector3.new(60, 1, 60), CFrame = CFrame.new(0, 0.02, -10), Color = MARBLE_DARK, Material = Enum.Material.Marble, Parent = folder })
	part({ Name = "ClubRug", Size = Vector3.new(26, 0.1, 26), CFrame = CFrame.new(-12, 0.58, -12), Color = Color3.fromRGB(38, 30, 48), Material = Enum.Material.Fabric, Parent = folder })
	for _, spec in {
		{ size = Vector3.new(60, 16, 1.5), cf = CFrame.new(0, 8, -40) },
		{ size = Vector3.new(1.5, 16, 60), cf = CFrame.new(-30, 8, -10) },
		{ size = Vector3.new(1.5, 16, 60), cf = CFrame.new(30, 8, -10) },
	} do
		part({ Name = "ClubWall", Size = spec.size, CFrame = spec.cf, Color = Color3.fromRGB(30, 26, 30), Material = Enum.Material.WoodPlanks, Parent = folder })
	end
	part({ Name = "ClubCeiling", Size = Vector3.new(60, 1, 60), CFrame = CFrame.new(0, 16.5, -10), Color = Color3.fromRGB(18, 16, 20), Parent = folder })
	chandelier(folder, Vector3.new(-12, 13.5, -12))
	chandelier(folder, Vector3.new(12, 13.5, -25))

	-- grand lounge: fireplace + seating circle
	part({ Name = "Fireplace", Size = Vector3.new(8, 7, 1.6), CFrame = CFrame.new(-12, 3.5, -39), Color = MARBLE_DARK, Material = Enum.Material.Marble, Parent = folder })
	local fire = part({ Name = "Fire", Size = Vector3.new(5, 2.6, 0.6), CFrame = CFrame.new(-12, 1.6, -38.6), Color = Color3.fromRGB(255, 140, 40), Material = Enum.Material.Neon, Parent = folder })
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 150, 60)
	fireLight.Brightness = 2
	fireLight.Range = 22
	fireLight.Parent = fire
	loungeSeat(folder, CFrame.new(-12, 0, -28) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(60, 46, 66))
	loungeSeat(folder, CFrame.new(-19, 0, -20) * CFrame.Angles(0, math.rad(-120), 0), Color3.fromRGB(60, 46, 66))
	loungeSeat(folder, CFrame.new(-5, 0, -20) * CFrame.Angles(0, math.rad(120), 0), Color3.fromRGB(60, 46, 66))
	part({ Name = "CoffeeTable", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 4.4, 4.4), CFrame = CFrame.new(-12, 0.55, -21) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })

	-- restaurant: bar + booths
	part({ Name = "Bar", Size = Vector3.new(14, 3.6, 2.4), CFrame = CFrame.new(18, 1.8, -34), Color = WALNUT, Material = Enum.Material.Wood, Parent = folder })
	part({ Name = "BarTop", Size = Vector3.new(14.6, 0.4, 3), CFrame = CFrame.new(18, 3.8, -34), Color = MARBLE, Material = Enum.Material.Marble, Parent = folder })
	part({ Name = "BarBack", Size = Vector3.new(14, 8, 0.8), CFrame = CFrame.new(18, 6, -39), Color = Color3.fromRGB(20, 18, 22), Parent = folder })
	local shelfGlow = part({ Name = "BarShelf", Size = Vector3.new(13, 0.3, 0.9), CFrame = CFrame.new(18, 6.5, -38.4), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, Parent = folder })
	local _2 = shelfGlow
	for i = 0, 4 do
		part({ Name = "BarStool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(12.5 + i * 2.6, 1.7, -31.4) * CFrame.Angles(0, 0, math.rad(90)), Color = VELVET, Material = Enum.Material.Fabric, Parent = folder })
	end
	for i = 0, 2 do
		local bz = -2 + i * 9
		part({ Name = "BoothSeat", Size = Vector3.new(2.2, 2.6, 7), CFrame = CFrame.new(28, 1.3, bz), Color = VELVET, Material = Enum.Material.Fabric, Parent = folder })
		part({ Name = "BoothTable", Size = Vector3.new(3.4, 0.4, 5), CFrame = CFrame.new(24.6, 2.6, bz), Color = WALNUT, Material = Enum.Material.Wood, Parent = folder })
		part({ Name = "BoothLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(24.6, 3.2, bz), Color = Color3.fromRGB(255, 226, 170), Material = Enum.Material.Neon, Parent = folder })
	end

	-- opportunity board + private rooms along west wall
	local board = part({ Name = "OpportunityBoard", Size = Vector3.new(1, 8, 14), CFrame = CFrame.new(-29, 6, 4), Color = Color3.fromRGB(14, 13, 16), Parent = folder })
	signText(board, "OPPORTUNITY BOARD\n\nprojects · collabs · openings", GOLD, Enum.NormalId.Right, 30)
	for i = 0, 1 do
		local rz = 6 - i * 14
		part({ Name = "PrivateRoomWall", Size = Vector3.new(12, 10, 0.8), CFrame = CFrame.new(-24, 5, rz - 5), Color = Color3.fromRGB(30, 26, 30), Material = Enum.Material.WoodPlanks, Parent = folder })
	end

	-- rooftop stair suggestion: gold spiral placeholder (portal pad)
	local roofPad = part({ Name = "RooftopPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6, 6), CFrame = CFrame.new(24, 0.75, 12) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Neon, Parent = folder })
	local _3 = roofPad

	-- ===== rooftop terrace (y 30, above the club) =====
	part({ Name = "RoofTerrace", Size = Vector3.new(60, 1, 60), CFrame = CFrame.new(0, 30, -10), Color = Color3.fromRGB(34, 34, 40), Material = Enum.Material.Slate, Parent = folder })
	for _, spec in {
		{ size = Vector3.new(60, 3, 0.6), cf = CFrame.new(0, 31.5, -40) },
		{ size = Vector3.new(60, 3, 0.6), cf = CFrame.new(0, 31.5, 20) },
		{ size = Vector3.new(0.6, 3, 60), cf = CFrame.new(-30, 31.5, -10) },
		{ size = Vector3.new(0.6, 3, 60), cf = CFrame.new(30, 31.5, -10) },
	} do
		part({ Name = "RoofRail", Size = spec.size, CFrame = spec.cf, Color = Color3.fromRGB(200, 210, 220), Material = Enum.Material.Glass, Transparency = 0.5, Parent = folder })
	end
	-- string lights
	for i = 0, 5 do
		part({ Name = "StringLight", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(-25 + i * 10, 35, -10), Color = Color3.fromRGB(255, 230, 180), Material = Enum.Material.Neon, Parent = folder })
	end
	loungeSeat(folder, CFrame.new(-10, 30.5, -20) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(46, 52, 66))
	loungeSeat(folder, CFrame.new(10, 30.5, -20) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(46, 52, 66))
	-- skyline silhouette boards around the plaza edge
	local rngSky = Random.new(5)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local d = 100
		local h = rngSky:NextNumber(20, 55)
		local b = part({ Name = "Skyline", Size = Vector3.new(rngSky:NextNumber(10, 22), h, 2), CFrame = CFrame.lookAt(Vector3.new(math.cos(a) * d, h / 2 - 1, math.sin(a) * d), Vector3.new(0, h / 2, 0)), Color = Color3.fromRGB(16, 18, 26), Parent = folder })
		for _ = 1, 6 do
			part({ Name = "SkylineWindow", Size = Vector3.new(1.2, 1.6, 0.2), CFrame = b.CFrame * CFrame.new(rngSky:NextNumber(-6, 6), rngSky:NextNumber(-h * 0.4, h * 0.4), -1.2), Color = Color3.fromRGB(255, 224, 140), Material = Enum.Material.Neon, Parent = folder })
		end
	end

	-- spawn in the plaza facing the entrance
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 84)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = folder

	return {
		folder = folder,
		doorGate = doorGate,
		counterLabel = counterLabel,
		receptionSpawn = Vector3.new(0, 2, 40),
		clubInterior = Vector3.new(0, 2, -4),
	}
end

return ClubMap
