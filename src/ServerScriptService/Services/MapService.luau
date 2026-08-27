--!strict
-- Generates all of Crumbworth High from parts at server start. No Studio assets needed.
-- Returns handles to everything other services attach behavior to.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

export type Plot = {
	index: number,
	model: Model,
	cframe: CFrame, -- origin at plot center, LookVector = toward the hallway
	floor: BasePart,
	gate: BasePart,
	lockSwitch: BasePart,
	collectPad: BasePart,
	sign: BasePart,
	signGui: SurfaceGui,
	pileBillboard: BillboardGui,
	pileLabel: TextLabel,
	deskSlots: { CFrame }, -- world CFrames for crew members
	halfSize: Vector2, -- (x, z) half extents for inside tests
}

export type Map = {
	plots: { Plot },
	conveyorStart: Vector3,
	conveyorEnd: Vector3,
	trophyCashBoard: BasePart,
	trophyAuraBoard: BasePart,
	cliqueBoards: { [string]: BasePart },
	dormBeds: { BasePart },
	detentionSpot: Vector3,
	folder: Folder,
}

local MapService = {}

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

-- Tag a part for the client-side EditableImage texture painter.
local function tag(p: BasePart, tagName: string): BasePart
	CollectionService:AddTag(p, tagName)
	return p
end

local function signText(parent: BasePart, text: string, textColor: Color3, face: Enum.NormalId?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	return gui
end

local function buildPlot(index: number, cf: CFrame, parent: Instance): Plot
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local width, depth = 62, 48 -- x, z in plot-local space (+Z local = front/hallway)

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(width, 1, depth),
		CFrame = cf * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(224, 218, 189),
		Parent = model,
	})

	-- locker wall along the back
	part({
		Name = "LockerWall",
		Size = Vector3.new(width - 4, 10, 2),
		CFrame = cf * CFrame.new(0, 5, -(depth / 2 - 1)),
		Color = Palette.LockerBlue,
		Parent = model,
	})
	-- locker detail: seams, handles, vents
	for i = 1, 7 do
		part({
			Name = "LockerSeam",
			Size = Vector3.new(0.4, 9, 0.4),
			CFrame = cf * CFrame.new(-24 + i * 6, 4.5, -(depth / 2 - 2.2)),
			Color = Palette.LockerBlueDark,
			Parent = model,
		})
	end
	for i = 0, 7 do
		local lockerX = -21 + i * 6
		part({
			Name = "LockerHandle",
			Size = Vector3.new(0.5, 1.2, 0.4),
			CFrame = cf * CFrame.new(lockerX + 1.8, 4.6, -(depth / 2 - 2.15)),
			Color = Palette.BusYellow,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		part({
			Name = "LockerVent",
			Size = Vector3.new(2.6, 0.5, 0.3),
			CFrame = cf * CFrame.new(lockerX, 7.6, -(depth / 2 - 2.1)),
			Color = Palette.LockerBlueDark,
			Parent = model,
		})
	end

	-- side rails so the plot reads as a room
	for _, side in { -1, 1 } do
		part({
			Name = "SideRail",
			Size = Vector3.new(1.5, 3, depth),
			CFrame = cf * CFrame.new(side * (width / 2 - 0.75), 1.5, 0),
			Color = Palette.LockerBlueDark,
			Parent = model,
		})
	end

	-- desks (crew slots): two rows of 6
	local deskSlots: { CFrame } = {}
	for row = 0, 1 do
		for col = 0, 5 do
			local x = -25 + col * 10
			local z = -6 - row * 11
			local deskCf = cf * CFrame.new(x, 0, z)
			part({
				Name = "Desk",
				Size = Vector3.new(4.5, 2.4, 3),
				CFrame = deskCf * CFrame.new(0, 1.2, 0),
				Color = Color3.fromRGB(160, 120, 76),
				Material = Enum.Material.Wood,
				Parent = model,
			})
			-- the student stands behind the desk, facing the front of the plot
			table.insert(deskSlots, deskCf * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, 0, 0))
		end
	end

	-- collect pad
	local collectPad = part({
		Name = "CollectPad",
		Size = Vector3.new(10, 0.4, 8),
		CFrame = cf * CFrame.new(0, 0.2, 16),
		Color = Palette.CashGreen,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local pileBillboard = Instance.new("BillboardGui")
	pileBillboard.Name = "PileBillboard"
	pileBillboard.Size = UDim2.fromScale(9, 2.4)
	pileBillboard.StudsOffset = Vector3.new(0, 6, 0)
	pileBillboard.AlwaysOnTop = true
	pileBillboard.MaxDistance = 110
	pileBillboard.Parent = collectPad
	local pileLabel = Instance.new("TextLabel")
	pileLabel.Size = UDim2.fromScale(1, 1)
	pileLabel.BackgroundTransparency = 1
	pileLabel.Font = Enum.Font.FredokaOne
	pileLabel.TextScaled = true
	pileLabel.TextColor3 = Palette.CashGreen
	pileLabel.TextStrokeTransparency = 0.4
	pileLabel.Text = "$0"
	pileLabel.Parent = pileBillboard

	-- lock switch
	local lockSwitch = part({
		Name = "LockSwitch",
		Size = Vector3.new(2, 5, 2),
		CFrame = cf * CFrame.new(width / 2 - 3, 2.5, 18),
		Color = Palette.DetentionRed,
		Parent = model,
	})

	-- laser gate across the entrance
	local gate = part({
		Name = "Gate",
		Size = Vector3.new(width, 12, 1),
		CFrame = cf * CFrame.new(0, 6, depth / 2),
		Color = Palette.CashGreen,
		Material = Enum.Material.ForceField,
		CanCollide = false,
		Transparency = 0.7,
		Parent = model,
	})

	-- name sign above the entrance
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(26, 5, 1),
		CFrame = cf * CFrame.new(0, 14, depth / 2),
		Color = Palette.Blackboard,
		Parent = model,
	})
	local signGui = signText(sign, "HOMEROOM " .. index, Palette.Chalk, Enum.NormalId.Front)
	-- also readable from the back
	signText(sign, "HOMEROOM " .. index, Palette.Chalk, Enum.NormalId.Back)

	model.Parent = parent

	return {
		index = index,
		model = model,
		cframe = cf,
		floor = floor,
		gate = gate,
		lockSwitch = lockSwitch,
		collectPad = collectPad,
		sign = sign,
		signGui = signGui,
		pileBillboard = pileBillboard,
		pileLabel = pileLabel,
		deskSlots = deskSlots,
		halfSize = Vector2.new(width / 2, depth / 2),
	}
end

local function buildZone(parent: Instance, name: string, center: Vector3, size: Vector2, color: Color3, label: string, material: Enum.Material?): BasePart
	local floor = part({
		Name = name .. "Floor",
		Size = Vector3.new(size.X, 1, size.Y),
		CFrame = CFrame.new(center) * CFrame.new(0, -0.5, 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local sign = part({
		Name = name .. "Sign",
		Size = Vector3.new(math.min(size.X - 4, 30), 5, 1),
		CFrame = CFrame.new(center) * CFrame.new(0, 11, -size.Y / 2 + 1),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(sign, label, Palette.Chalk, Enum.NormalId.Front)
	signText(sign, label, Palette.Chalk, Enum.NormalId.Back)
	local post = part({
		Name = name .. "SignPost",
		Size = Vector3.new(1, 9, 1),
		CFrame = CFrame.new(center) * CFrame.new(0, 4.5, -size.Y / 2 + 1),
		Color = Palette.LockerBlueDark,
		Parent = parent,
	})
	post.Transparency = 0
	return floor
end

-- ===== decorations (all parts, no assets) =====

local function buildBus(parent: Instance, cf: CFrame)
	local body = part({
		Name = "BusBody",
		Size = Vector3.new(24, 9, 9),
		CFrame = cf * CFrame.new(0, 6.5, 0),
		Color = Palette.BusYellow,
		Parent = parent,
	})
	part({
		Name = "BusHood",
		Size = Vector3.new(4, 5, 9),
		CFrame = cf * CFrame.new(14, 4.5, 0),
		Color = Palette.BusYellow,
		Parent = parent,
	})
	-- windows strip
	part({
		Name = "BusWindows",
		Size = Vector3.new(20, 3, 9.2),
		CFrame = cf * CFrame.new(0, 8, 0),
		Color = Color3.fromRGB(140, 190, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Parent = parent,
	})
	-- stripe
	part({
		Name = "BusStripe",
		Size = Vector3.new(24.2, 0.8, 9.3),
		CFrame = cf * CFrame.new(0, 5.4, 0),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	-- wheels
	for _, offset in { Vector3.new(-8, 2, 4.6), Vector3.new(8, 2, 4.6), Vector3.new(-8, 2, -4.6), Vector3.new(8, 2, -4.6) } do
		local wheel = part({
			Name = "BusWheel",
			Size = Vector3.new(3.4, 3.4, 1.2),
			CFrame = cf * CFrame.new(offset) * CFrame.Angles(0, math.rad(90), math.rad(90)),
			Color = Color3.fromRGB(30, 30, 30),
			Parent = parent,
		})
		wheel.Shape = Enum.PartType.Cylinder
	end
	local sign = part({
		Name = "BusSign",
		Size = Vector3.new(18, 2.2, 0.4),
		CFrame = cf * CFrame.new(0, 10.6, 0),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(sign, "CRUMBWORTH HIGH", Palette.BusYellow, Enum.NormalId.Front)
	signText(sign, "CRUMBWORTH HIGH", Palette.BusYellow, Enum.NormalId.Back)
	local _ = body
end

local function buildHallwayLights(parent: Instance)
	for x = -120, 120, 60 do
		for _, side in { -1, 1 } do
			part({
				Name = "LightPost",
				Size = Vector3.new(1, 13, 1),
				CFrame = CFrame.new(x, 6.5, side * 13.5),
				Color = Palette.LockerBlueDark,
				Parent = parent,
			})
		end
		local beam = part({
			Name = "LightBeam",
			Size = Vector3.new(1.4, 1, 28),
			CFrame = CFrame.new(x, 13.5, 0),
			Color = Palette.Chalk,
			Parent = parent,
		})
		local strip = part({
			Name = "LightStrip",
			Size = Vector3.new(0.8, 0.4, 24),
			CFrame = CFrame.new(x, 12.9, 0),
			Color = Color3.fromRGB(255, 245, 210),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 0.8
		light.Range = 26
		light.Color = Color3.fromRGB(255, 240, 200)
		light.Parent = strip
		local _ = beam
	end
end

local function buildBenches(parent: Instance)
	for x = -90, 90, 60 do
		for _, side in { -1, 1 } do
			local cf = CFrame.new(x + 30, 0, side * 20)
			part({
				Name = "BenchSeat",
				Size = Vector3.new(8, 0.8, 2.4),
				CFrame = cf * CFrame.new(0, 1.6, 0),
				Color = Color3.fromRGB(160, 120, 76),
				Material = Enum.Material.Wood,
				Parent = parent,
			})
			for _, legX in { -3.2, 3.2 } do
				part({
					Name = "BenchLeg",
					Size = Vector3.new(0.8, 1.6, 2.4),
					CFrame = cf * CFrame.new(legX, 0.8, 0),
					Color = Palette.LockerBlueDark,
					Parent = parent,
				})
			end
		end
	end
end

local function buildCafeteriaTables(parent: Instance, center: Vector3)
	for _, offset in { Vector3.new(-18, 0, -18), Vector3.new(18, 0, -18), Vector3.new(-18, 0, 14), Vector3.new(18, 0, 14) } do
		local pos = center + offset
		local top = part({
			Name = "TableTop",
			Size = Vector3.new(1, 10, 10),
			CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(222, 100, 90),
			Parent = parent,
		})
		top.Shape = Enum.PartType.Cylinder
		part({
			Name = "TableLeg",
			Size = Vector3.new(1.2, 3, 1.2),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)),
			Color = Color3.fromRGB(120, 120, 120),
			Parent = parent,
		})
	end
end

local function buildTree(parent: Instance, pos: Vector3, scale: number)
	part({
		Name = "TreeTrunk",
		Size = Vector3.new(1.8 * scale, 7 * scale, 1.8 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)),
		Color = Color3.fromRGB(105, 76, 48),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	for i, offset in { Vector3.new(0, 8 * scale, 0), Vector3.new(1.6 * scale, 6.6 * scale, 1.2 * scale), Vector3.new(-1.5 * scale, 6.9 * scale, -1 * scale) } do
		local leaves = part({
			Name = "TreeLeaves",
			Size = Vector3.one * (4.6 - i * 0.5) * scale,
			CFrame = CFrame.new(pos + offset),
			Color = Color3.fromRGB(88 + i * 10, 160 + i * 8, 78),
			Material = Enum.Material.Grass,
			Parent = parent,
		})
		leaves.Shape = Enum.PartType.Ball
	end
end

local function buildGymMarkings(parent: Instance, center: Vector3)
	local circle = part({
		Name = "GymCircle",
		Size = Vector3.new(0.2, 26, 26),
		CFrame = CFrame.new(center + Vector3.new(0, 0.11, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Palette.White,
		Parent = parent,
	})
	circle.Shape = Enum.PartType.Cylinder
	local inner = part({
		Name = "GymCircleInner",
		Size = Vector3.new(0.22, 23, 23),
		CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(210, 160, 110),
		Parent = parent,
	})
	inner.Shape = Enum.PartType.Cylinder
	part({
		Name = "GymCenterLine",
		Size = Vector3.new(66, 0.2, 1.2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.13, 0)),
		Color = Palette.White,
		Parent = parent,
	})
end

local function buildStatues(parent: Instance)
	local StudentGen = require(script.Parent.StudentGen) :: any
	for i, spec in { { id = "school_legend", x = 215 - 14 }, { id = "substitute_who_stayed", x = 215 + 14 } } do
		local pedestal = part({
			Name = "StatuePedestal",
			Size = Vector3.new(6, 3, 6),
			CFrame = CFrame.new(spec.x, 1.5, -78),
			Color = Color3.fromRGB(200, 200, 200),
			Material = Enum.Material.Marble,
			Parent = parent,
		})
		local model = StudentGen.Create(spec.id)
		if model then
			-- solid gold repaint
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then
					child.Color = Palette.BusYellow
					child.Material = Enum.Material.Metal
					child.Anchored = true
				elseif child:IsA("BillboardGui") or child:IsA("ParticleEmitter") or child:IsA("Highlight") then
					child:Destroy()
				end
			end
			model.Name = "Statue" .. i
			model.Parent = parent
			StudentGen.Stand(model, pedestal.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(180), 0))
		end
		local _ = i
	end
end

-- Stepped roof + warm interior lighting for a walled building.
local function buildRoof(parent: Instance, center: Vector3, size: Vector2)
	local layers = {
		{ inset = -4, y = 14.75 },
		{ inset = 8, y = 16.25 },
		{ inset = 20, y = 17.75 },
		{ inset = 32, y = 19.25 },
	}
	for _, layer in layers do
		if size.X - layer.inset > 6 and size.Y - layer.inset > 6 then
			part({
				Name = "RoofLayer",
				Size = Vector3.new(size.X - layer.inset, 1.5, size.Y - layer.inset),
				CFrame = CFrame.new(center + Vector3.new(0, layer.y, 0)),
				Color = Color3.fromRGB(84, 98, 110),
				Material = Enum.Material.ClayRoofTiles,
				Parent = parent,
			})
		end
	end
	-- interior ceiling lights so roofed rooms stay warm and readable
	for _, offset in { Vector3.new(-size.X / 5, 0, 0), Vector3.new(size.X / 5, 0, 0) } do
		local strip = part({
			Name = "CeilingLight",
			Size = Vector3.new(1, 0.4, size.Y * 0.5),
			CFrame = CFrame.new(center + offset + Vector3.new(0, 13.6, 0)),
			Color = Color3.fromRGB(255, 244, 214),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 34
		light.Color = Color3.fromRGB(255, 238, 200)
		light.Parent = strip
	end
end

-- Concrete walkway between two points.
local function buildPath(parent: Instance, from: Vector3, to: Vector3, width: number)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local mid = (from + to) / 2
	part({
		Name = "Walkway",
		Size = Vector3.new(width, 0.3, length),
		CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.05, mid.Z), Vector3.new(to.X, 0.05, to.Z)),
		Color = Color3.fromRGB(178, 172, 160),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
end

-- Courtyard fountain: stone basin, water, spray.
local function buildFountain(parent: Instance, center: Vector3)
	local basin = part({
		Name = "FountainBasin",
		Size = Vector3.new(2.5, 16, 16),
		CFrame = CFrame.new(center + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 190, 190),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	basin.Shape = Enum.PartType.Cylinder
	local water = part({
		Name = "FountainWater",
		Size = Vector3.new(1.2, 14, 14),
		CFrame = CFrame.new(center + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 160, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Parent = parent,
	})
	water.Shape = Enum.PartType.Cylinder
	local column = part({
		Name = "FountainColumn",
		Size = Vector3.new(1.6, 5, 1.6),
		CFrame = CFrame.new(center + Vector3.new(0, 3.5, 0)),
		Color = Color3.fromRGB(190, 190, 190),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
	spray.Rate = 24
	spray.Lifetime = NumberRange.new(0.7, 1.1)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.Size = NumberSequence.new(0.35)
	spray.Transparency = NumberSequence.new(0.35)
	spray.LightEmission = 0.4
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = column
end

-- Banners hanging under the hallway canopy.
local function buildBanners(parent: Instance)
	local colors = { Palette.DetentionRed, Palette.LockerBlue, Palette.BusYellow, Palette.AuraPurple }
	local texts = { "GO LEGENDS!", "QUIZ FRIDAY", "LOCK YOUR BASE", "FARM AURA" }
	for i = 1, 4 do
		local banner = part({
			Name = "Banner" .. i,
			Size = Vector3.new(8, 4.5, 0.3),
			CFrame = CFrame.new(-90 + (i - 1) * 60, 11.6, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = colors[i],
			Parent = parent,
		})
		signText(banner, texts[i], Palette.White, Enum.NormalId.Front)
		signText(banner, texts[i], Palette.White, Enum.NormalId.Back)
	end
end

-- Three walls + a window band around a zone, leaving the side facing `openDir` open.
local function buildZoneWalls(parent: Instance, center: Vector3, size: Vector2, openDir: Vector3)
	local height = 14
	local sides = {
		{ dir = Vector3.new(0, 0, -1), cf = CFrame.new(center + Vector3.new(0, 0, -size.Y / 2)), len = size.X },
		{ dir = Vector3.new(0, 0, 1), cf = CFrame.new(center + Vector3.new(0, 0, size.Y / 2)), len = size.X },
		{ dir = Vector3.new(-1, 0, 0), cf = CFrame.new(center + Vector3.new(-size.X / 2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0), len = size.Y },
		{ dir = Vector3.new(1, 0, 0), cf = CFrame.new(center + Vector3.new(size.X / 2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0), len = size.Y },
	}
	for _, side in sides do
		if side.dir:Dot(openDir) > 0.5 then
			continue
		end
		-- lower wall, window band, upper band
		part({
			Name = "ZoneWallLower",
			Size = Vector3.new(side.len, 6, 2),
			CFrame = side.cf * CFrame.new(0, 3, 0),
			Color = Color3.fromRGB(226, 218, 196),
			Material = Enum.Material.Brick,
			Parent = parent,
		})
		part({
			Name = "ZoneWallWindows",
			Size = Vector3.new(side.len, 4, 1.2),
			CFrame = side.cf * CFrame.new(0, 8, 0),
			Color = Color3.fromRGB(150, 200, 225),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			Parent = parent,
		})
		-- window mullions
		local mullions = math.floor(side.len / 9)
		for m = 1, mullions - 1 do
			part({
				Name = "WindowMullion",
				Size = Vector3.new(0.5, 4, 1.4),
				CFrame = side.cf * CFrame.new(-side.len / 2 + m * 9, 8, 0),
				Color = Color3.fromRGB(226, 218, 196),
				Material = Enum.Material.Concrete,
				Parent = parent,
			})
		end
		part({
			Name = "ZoneWallUpper",
			Size = Vector3.new(side.len, height - 10, 2),
			CFrame = side.cf * CFrame.new(0, 10 + (height - 10) / 2, 0),
			Color = Color3.fromRGB(226, 218, 196),
			Material = Enum.Material.Brick,
			Parent = parent,
		})
	end
end

local function buildEntranceArch(parent: Instance)
	for _, x in { -20, 20 } do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(4, 18, 4),
			CFrame = CFrame.new(x, 9, 104),
			Color = Color3.fromRGB(150, 100, 70),
			Material = Enum.Material.Brick,
			Parent = parent,
		})
	end
	local beam = part({
		Name = "ArchBeam",
		Size = Vector3.new(48, 6, 3),
		CFrame = CFrame.new(0, 20, 104),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(beam, "CRUMBWORTH HIGH", Palette.BusYellow, Enum.NormalId.Front)
	signText(beam, "GO LEGENDS!", Palette.BusYellow, Enum.NormalId.Back)
end

local function buildFlagpole(parent: Instance)
	part({
		Name = "Flagpole",
		Size = Vector3.new(0.8, 26, 0.8),
		CFrame = CFrame.new(0, 13, 150),
		Color = Color3.fromRGB(190, 190, 195),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local flag = part({
		Name = "Flag",
		Size = Vector3.new(9, 5, 0.3),
		CFrame = CFrame.new(5.3, 22.5, 150),
		Color = Palette.CashGreen,
		Parent = parent,
	})
	signText(flag, "$", Palette.BusYellow, Enum.NormalId.Front)
	signText(flag, "$", Palette.BusYellow, Enum.NormalId.Back)
end

local function buildHoops(parent: Instance, center: Vector3)
	for _, side in { -1, 1 } do
		local base = center + Vector3.new(side * 30, 0, 0)
		part({
			Name = "HoopPole",
			Size = Vector3.new(1, 12, 1),
			CFrame = CFrame.new(base + Vector3.new(0, 6, 0)),
			Color = Color3.fromRGB(190, 190, 195),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		part({
			Name = "HoopBoard",
			Size = Vector3.new(1, 4.5, 7),
			CFrame = CFrame.new(base + Vector3.new(side * -0.9, 11.5, 0)),
			Color = Palette.White,
			Parent = parent,
		})
		local ring = part({
			Name = "HoopRing",
			Size = Vector3.new(0.4, 2.6, 2.6),
			CFrame = CFrame.new(base + Vector3.new(side * -2.6, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(230, 120, 60),
			Parent = parent,
		})
		ring.Shape = Enum.PartType.Cylinder
	end
	local board = part({
		Name = "GymScoreboard",
		Size = Vector3.new(16, 8, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 12, -34)),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(board, "LEGENDS 21\nVISITORS 3", Palette.BusYellow, Enum.NormalId.Front)
end

-- Glass canopy over the main hallway: tinted panels on the existing light beams.
local function buildCanopy(parent: Instance)
	for x = -150, 150, 60 do
		part({
			Name = "CanopyPanel",
			Size = Vector3.new(60, 0.5, 30),
			CFrame = CFrame.new(x + 30 <= 150 and x + 30 or 150, 14.4, 0),
			Color = Color3.fromRGB(160, 205, 230),
			Material = Enum.Material.Glass,
			Transparency = 0.55,
			Parent = parent,
		})
	end
	for _, side in { -1, 1 } do
		part({
			Name = "CanopyEdge",
			Size = Vector3.new(320, 0.8, 1.2),
			CFrame = CFrame.new(0, 14.4, side * 14.6),
			Color = Palette.LockerBlueDark,
			Parent = parent,
		})
	end
end

-- Checkered cafeteria floor tiles.
local function buildCheckerFloor(parent: Instance, center: Vector3, size: Vector2)
	local tile = 10
	local cols, rows = math.floor(size.X / tile), math.floor(size.Y / tile)
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			if (i + j) % 2 == 0 then
				part({
					Name = "CheckerTile",
					Size = Vector3.new(tile - 0.4, 0.2, tile - 0.4),
					CFrame = CFrame.new(
						center.X - size.X / 2 + tile / 2 + i * tile,
						0.11,
						center.Z - size.Y / 2 + tile / 2 + j * tile
					),
					Color = Color3.fromRGB(222, 100, 90),
					Parent = parent,
				})
			end
		end
	end
end

-- Flowerbeds: planter box + colored flower balls.
local function buildFlowerbed(parent: Instance, center: Vector3)
	part({
		Name = "PlanterBox",
		Size = Vector3.new(10, 1.6, 4),
		CFrame = CFrame.new(center + Vector3.new(0, 0.8, 0)),
		Color = Color3.fromRGB(105, 76, 48),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local rng = Random.new(math.floor(center.X * 13 + center.Z * 7))
	local colors = {
		Color3.fromRGB(240, 96, 130),
		Color3.fromRGB(245, 197, 49),
		Color3.fromRGB(180, 75, 217),
		Color3.fromRGB(255, 255, 255),
	}
	for i = 1, 6 do
		local flower = part({
			Name = "Flower",
			Size = Vector3.one * rng:NextNumber(0.9, 1.4),
			CFrame = CFrame.new(center + Vector3.new(-4 + i * 1.35, 1.9 + rng:NextNumber(0, 0.3), rng:NextNumber(-1, 1))),
			Color = colors[rng:NextInteger(1, #colors)],
			Parent = parent,
		})
		flower.Shape = Enum.PartType.Ball
	end
end

-- Ambient falling leaves over the courtyard.
local function buildLeaves(parent: Instance, center: Vector3)
	local emitterPart = part({
		Name = "LeafEmitter",
		Size = Vector3.new(100, 1, 60),
		CFrame = CFrame.new(center + Vector3.new(0, 26, 0)),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	local leaves = Instance.new("ParticleEmitter")
	leaves.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 190, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 180, 70)),
	})
	leaves.Rate = 4
	leaves.Lifetime = NumberRange.new(6, 9)
	leaves.Speed = NumberRange.new(2, 4)
	leaves.Acceleration = Vector3.new(1.5, -2.5, 0.8)
	leaves.Rotation = NumberRange.new(0, 360)
	leaves.RotSpeed = NumberRange.new(-90, 90)
	leaves.Size = NumberSequence.new(0.35)
	leaves.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.9, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	leaves.EmissionDirection = Enum.NormalId.Bottom
	leaves.Parent = emitterPart
end

local function buildRoad(parent: Instance)
	part({
		Name = "Road",
		Size = Vector3.new(200, 0.4, 16),
		CFrame = CFrame.new(-160, -0.3, 120),
		Color = Color3.fromRGB(70, 70, 74),
		Material = Enum.Material.Asphalt,
		Parent = parent,
	})
	for x = -240, -80, 20 do
		part({
			Name = "RoadStripe",
			Size = Vector3.new(6, 0.2, 0.8),
			CFrame = CFrame.new(x, -0.05, 120),
			Color = Palette.BusYellow,
			Parent = parent,
		})
	end
end


-- School props that fill the space: vending machines, bins, notice boards,
-- water fountains, planters. Placed along the hallway edges and in the zones.
local function buildProps(parent: Instance)
	local function vending(x: number, z: number, yaw: number, color: Color3)
		local body = part({
			Name = "VendingMachine",
			Size = Vector3.new(6, 11, 3.5),
			CFrame = CFrame.new(x, 5.5, z) * CFrame.Angles(0, yaw, 0),
			Color = color,
			Parent = parent,
		})
		part({
			Name = "VendingGlass",
			Size = Vector3.new(4.4, 7, 0.4),
			CFrame = body.CFrame * CFrame.new(0, 1.4, -1.8),
			Color = Color3.fromRGB(40, 50, 60),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Parent = parent,
		})
		for row = 0, 2 do
			part({
				Name = "VendingShelf",
				Size = Vector3.new(4.2, 0.3, 0.5),
				CFrame = body.CFrame * CFrame.new(0, 3.4 - row * 2.1, -1.9),
				Color = Color3.fromRGB(180, 180, 185),
				Parent = parent,
			})
		end
		local glow = part({
			Name = "VendingGlow",
			Size = Vector3.new(5, 0.6, 0.3),
			CFrame = body.CFrame * CFrame.new(0, 5, -1.85),
			Color = Palette.BusYellow,
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 1
		light.Range = 16
		light.Color = Palette.BusYellow
		light.Parent = glow
	end

	local function bin(x: number, z: number)
		local body = part({
			Name = "TrashBin",
			Size = Vector3.new(3.4, 4.4, 3.4),
			CFrame = CFrame.new(x, 2.2, z),
			Color = Color3.fromRGB(70, 78, 68),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		body.Shape = Enum.PartType.Cylinder
		body.CFrame = CFrame.new(x, 2.2, z) * CFrame.Angles(0, 0, math.rad(90))
		part({
			Name = "TrashLid",
			Size = Vector3.new(0.5, 3.8, 3.8),
			CFrame = CFrame.new(x, 4.6, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(45, 52, 44),
			Material = Enum.Material.Metal,
			Parent = parent,
		}).Shape = Enum.PartType.Cylinder
	end

	local function noticeBoard(x: number, z: number, yaw: number)
		local board = part({
			Name = "NoticeBoard",
			Size = Vector3.new(10, 7, 0.6),
			CFrame = CFrame.new(x, 6, z) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(120, 88, 56),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		local rng = Random.new(math.floor(x * 7 + z * 3))
		for i = 1, 6 do
			part({
				Name = "Flyer",
				Size = Vector3.new(rng:NextNumber(1.6, 2.4), rng:NextNumber(2, 2.8), 0.15),
				CFrame = board.CFrame
					* CFrame.new(rng:NextNumber(-3.6, 3.6), rng:NextNumber(-2, 2), -0.4)
					* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
				Color = ({
					Color3.fromRGB(245, 245, 235),
					Color3.fromRGB(250, 220, 160),
					Color3.fromRGB(200, 235, 245),
				})[rng:NextInteger(1, 3)],
				Parent = parent,
			})
		end
	end

	local function fountain(x: number, z: number, yaw: number)
		part({
			Name = "WaterFountain",
			Size = Vector3.new(3.6, 3.6, 2.4),
			CFrame = CFrame.new(x, 1.8, z) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(200, 205, 210),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		part({
			Name = "FountainBowl",
			Size = Vector3.new(3.2, 0.5, 2),
			CFrame = CFrame.new(x, 3.6, z) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(225, 230, 235),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end

	local function planter(x: number, z: number)
		part({
			Name = "PlanterPot",
			Size = Vector3.new(3.4, 3, 3.4),
			CFrame = CFrame.new(x, 1.5, z),
			Color = Color3.fromRGB(160, 96, 70),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
		local rng = Random.new(math.floor(x * 11 + z * 5))
		for i = 1, 4 do
			local leaf = part({
				Name = "PlantLeaf",
				Size = Vector3.one * rng:NextNumber(2, 3.2),
				CFrame = CFrame.new(x + rng:NextNumber(-1, 1), 4 + rng:NextNumber(0, 1.4), z + rng:NextNumber(-1, 1)),
				Color = Color3.fromRGB(70, 140 + i * 8, 60),
				Material = Enum.Material.Grass,
				Parent = parent,
			})
			leaf.Shape = Enum.PartType.Ball
		end
	end

	-- hallway furniture, alternating along both sides
	for i, x in { -145, -105, -65, -25, 15, 55, 95, 135 } do
		local z = (i % 2 == 0) and -12.5 or 12.5
		local yaw = (i % 2 == 0) and 0 or math.pi
		local kind = i % 4
		if kind == 0 then
			vending(x, z, yaw, Palette.DetentionRed)
		elseif kind == 1 then
			noticeBoard(x, z, yaw)
		elseif kind == 2 then
			vending(x, z, yaw, Palette.LockerBlue)
		else
			fountain(x, z, yaw)
		end
		bin(x + 12, z * 0.86)
		planter(x + 22, z * 0.9)
	end

	-- cafeteria + gym extras
	vending(-186, 40, math.pi / 2, Palette.CashGreen)
	vending(-186, 78, math.pi / 2, Palette.BusYellow)
	bin(-192, 60)
	for _, spot in { Vector3.new(196, 34, 0), Vector3.new(196, 86, 0) } do
		bin(spot.X, spot.Y)
	end
	planter(-40, 100)
	planter(40, 100)
end

-- Dense treeline just inside the perimeter walls, so the horizon reads as woods.
local function buildTreeline(parent: Instance, treeFn: (Instance, Vector3, number) -> ())
	local rng = Random.new(2026)
	for i = 1, 90 do
		local angle = (i / 90) * math.pi * 2
		local dist = rng:NextNumber(238, 268)
		local pos = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		treeFn(parent, pos, rng:NextNumber(1.1, 2.3))
	end
end

local function buildPerimeter(parent: Instance)
	for _, spec in {
		{ size = Vector3.new(560, 6, 2), cf = CFrame.new(0, 3, -279) },
		{ size = Vector3.new(560, 6, 2), cf = CFrame.new(0, 3, 279) },
		{ size = Vector3.new(2, 6, 560), cf = CFrame.new(-279, 3, 0) },
		{ size = Vector3.new(2, 6, 560), cf = CFrame.new(279, 3, 0) },
	} do
		part({
			Name = "PerimeterWall",
			Size = spec.size,
			CFrame = spec.cf,
			Color = Color3.fromRGB(150, 100, 70),
			Material = Enum.Material.Brick,
			Parent = parent,
		})
	end
end

-- Real terrain: grass base under the campus + rolling hills outside the walls.
local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -2.1, 0), Vector3.new(680, 4, 680), Enum.Material.Grass)
	local rng = Random.new(7)
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2
		local dist = rng:NextNumber(430, 520)
		local pos = Vector3.new(math.cos(angle) * dist, rng:NextNumber(-6, 8), math.sin(angle) * dist)
		terrain:FillBall(pos, rng:NextNumber(28, 64), Enum.Material.Grass)
	end
	-- hard rule: nothing rises above ground level anywhere inside the walls
	terrain:FillBlock(CFrame.new(0, 34, 0), Vector3.new(640, 64, 640), Enum.Material.Air)

	-- no terrain (or its animated grass blades) under any interior floor
	terrain.Decoration = false
	for _, region in {
		{ cf = CFrame.new(0, -2.3, 0), size = Vector3.new(330, 5, 162) }, -- main building
		{ cf = CFrame.new(-215, -2.3, 60), size = Vector3.new(64, 5, 64) },
		{ cf = CFrame.new(-215, -2.3, -60), size = Vector3.new(64, 5, 64) },
		{ cf = CFrame.new(215, -2.3, 60), size = Vector3.new(64, 5, 64) },
		{ cf = CFrame.new(215, -2.3, -60), size = Vector3.new(64, 5, 64) },
		{ cf = CFrame.new(0, -2.3, -150), size = Vector3.new(74, 5, 54) },
		{ cf = CFrame.new(-195, -2.3, 200), size = Vector3.new(64, 5, 54) },
		{ cf = CFrame.new(195, -2.3, 200), size = Vector3.new(64, 5, 54) },
		{ cf = CFrame.new(-100, -2.3, -210), size = Vector3.new(30, 5, 22) },
	} do
		terrain:FillBlock(region.cf, region.size, Enum.Material.Air)
	end

	-- a few distant rocky peaks for the horizon
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + 0.3
		local dist = rng:NextNumber(430, 520)
		local pos = Vector3.new(math.cos(angle) * dist, rng:NextNumber(10, 30), math.sin(angle) * dist)
		terrain:FillBall(pos, rng:NextNumber(40, 80), Enum.Material.Rock)
	end
end


-- A wall run with door gaps: brick base, window band, brick top, parapet cap.
local function buildWallRun(parent: Instance, from: Vector3, to: Vector3, gaps: { { at: number, width: number } }, tall: boolean?)
	local dir = (to - from)
	local length = dir.Magnitude
	local unit = dir.Unit
	local perp = Vector3.new(-unit.Z, 0, unit.X)
	local cuts = { 0, length }
	for _, gap in gaps do
		table.insert(cuts, math.clamp(gap.at - gap.width / 2, 0, length))
		table.insert(cuts, math.clamp(gap.at + gap.width / 2, 0, length))
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		-- odd segments are wall, even segments are gaps (cuts alternate)
		local a, b = cuts[i], cuts[i + 1]
		local isGap = false
		for _, gap in gaps do
			local mid = (a + b) / 2
			if mid > gap.at - gap.width / 2 and mid < gap.at + gap.width / 2 then
				isGap = true
				break
			end
		end
		local segLen = b - a
		if isGap or segLen < 1 then
			continue
		end
		local mid = from + unit * ((a + b) / 2)
		local cf = CFrame.lookAt(mid, mid + perp)
		tag(part({ Name = "ShellBrickLow", Size = Vector3.new(segLen, 6, 2), CFrame = cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
		tag(part({ Name = "ShellWindow", Size = Vector3.new(segLen, 4, 1.2), CFrame = cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }), "TexWindow")
		local mullions = math.floor(segLen / 9)
		for m2 = 1, mullions - 1 do
			part({ Name = "ShellMullion", Size = Vector3.new(0.5, 4, 1.4), CFrame = cf * CFrame.new(-segLen / 2 + m2 * 9, 8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
		tag(part({ Name = "ShellBrickHigh", Size = Vector3.new(segLen, 6, 2), CFrame = cf * CFrame.new(0, 13, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
		-- white frames around the first-story windows (reference-art trim)
		part({ Name = "ShellSill", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 5.8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "ShellLintel", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 10.2, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		if tall then
			-- second story: floor band, framed window band, brick, high parapet
			part({ Name = "ShellFloorBand", Size = Vector3.new(segLen, 1.4, 2.6), CFrame = cf * CFrame.new(0, 16.6, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			tag(part({ Name = "ShellWindow2", Size = Vector3.new(segLen, 4, 1.2), CFrame = cf * CFrame.new(0, 19.5, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }), "TexWindow")
			local mullions2 = math.floor(segLen / 9)
			for m3 = 1, mullions2 - 1 do
				part({ Name = "ShellMullion2", Size = Vector3.new(0.5, 4, 1.4), CFrame = cf * CFrame.new(-segLen / 2 + m3 * 9, 19.5, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			end
			part({ Name = "ShellLintel2", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 21.8, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			tag(part({ Name = "ShellBrickTop", Size = Vector3.new(segLen, 3.6, 2), CFrame = cf * CFrame.new(0, 24, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
			part({ Name = "ShellParapet", Size = Vector3.new(segLen + 0.6, 1.2, 2.8), CFrame = cf * CFrame.new(0, 26.4, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		else
			part({ Name = "ShellParapet", Size = Vector3.new(segLen + 0.6, 1.2, 2.8), CFrame = cf * CFrame.new(0, 16.6, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	-- door frames at each gap
	for _, gap in gaps do
		local mid = from + unit * gap.at
		local cf = CFrame.lookAt(mid, mid + perp)
		for _, side in { -1, 1 } do
			part({ Name = "DoorPost", Size = Vector3.new(1.6, 12, 2.6), CFrame = cf * CFrame.new(side * (gap.width / 2 + 0.8), 6, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
		part({ Name = "DoorLintel", Size = Vector3.new(gap.width + 4, 2, 2.8), CFrame = cf * CFrame.new(0, 13, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		if tall then
			-- fill the second story above the doorway so the wall reads solid
			tag(part({ Name = "GapUpperBrick", Size = Vector3.new(gap.width + 4, 12.4, 2), CFrame = cf * CFrame.new(0, 20.2, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
			part({ Name = "GapParapet", Size = Vector3.new(gap.width + 4, 1.2, 2.8), CFrame = cf * CFrame.new(0, 26.4, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		end
	end
end

-- The main school becomes a real building: an outer shell around the hallway
-- and all eight homerooms, wing roofs, interior lights, and a grand entrance.
local function buildMainShell(parent: Instance)
	local x0, x1, z0, z1 = -168, 168, -84, 84
	buildWallRun(parent, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), { { at = 168, width = 16 } }, true) -- north (path to classroom)
	buildWallRun(parent, Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), { { at = 168, width = 30 } }, true) -- south (main entrance)
	buildWallRun(parent, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), { { at = 84, width = 30 } }, true) -- west hallway mouth
	buildWallRun(parent, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), { { at = 84, width = 30 } }, true) -- east hallway mouth

	-- gabled slate roofs over the homeroom rows (skylight strip stays over the hallway)
	local pitch = math.rad(12)
	for _, zc in { -55, 55 } do
		for _, side in { -1, 1 } do
			tag(part({
				Name = "WingRoofSlope",
				Size = Vector3.new(336, 1.2, 30.6),
				CFrame = CFrame.new(0, 29.8, zc + side * 14.5) * CFrame.Angles(side * pitch, 0, 0),
				Color = Color3.fromRGB(62, 78, 70),
				Material = Enum.Material.Slate,
				Parent = parent,
			}), "TexRoof")
		end
		part({ Name = "WingRidge", Size = Vector3.new(336, 0.9, 2.4), CFrame = CFrame.new(0, 33.2, zc), Color = Color3.fromRGB(52, 64, 58), Material = Enum.Material.Slate, Parent = parent })
		part({ Name = "WingCeiling", Size = Vector3.new(336, 0.8, 58), CFrame = CFrame.new(0, 26.6, zc), Color = Color3.fromRGB(214, 210, 200), Material = Enum.Material.SmoothPlastic, Parent = parent })
	end
	-- interior lights above each homeroom
	for _, zc in { -52, 52 } do
		for _, xc in { -117, -39, 39, 117 } do
			local strip = part({ Name = "WingLight", Size = Vector3.new(26, 0.4, 1), CFrame = CFrame.new(xc, 15.6, zc), Color = Color3.fromRGB(255, 244, 214), Material = Enum.Material.Neon, Parent = parent })
			local light = Instance.new("PointLight")
			light.Brightness = 1.1
			light.Range = 36
			light.Color = Color3.fromRGB(255, 238, 200)
			light.Parent = strip
		end
	end

	-- grand entrance: steps, columns, facade sign
	part({ Name = "EntranceStepLow", Size = Vector3.new(34, 1, 8), CFrame = CFrame.new(0, 0.5, 90), Color = Color3.fromRGB(200, 196, 186), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "EntranceStepHigh", Size = Vector3.new(30, 1, 5), CFrame = CFrame.new(0, 1.0, 87), Color = Color3.fromRGB(214, 210, 200), Material = Enum.Material.Concrete, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "EntranceColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(15, 2.6, 2.6), CFrame = CFrame.new(side * 17, 7.5, 87) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
	end
	local facade = part({ Name = "FacadeSign", Size = Vector3.new(52, 5.4, 1.4), CFrame = CFrame.new(0, 24.4, 84.4), Color = Color3.fromRGB(24, 32, 58), Parent = parent })
	signText(facade, "DETENTION", Color3.fromRGB(255, 196, 60), Enum.NormalId.Front)
	signText(facade, "DETENTION", Color3.fromRGB(255, 196, 60), Enum.NormalId.Back)

	-- brick clock tower rising over the entrance (the campus landmark)
	local towerBrick = Color3.fromRGB(126, 78, 62)
	tag(part({ Name = "ClockTower", Size = Vector3.new(14, 34, 14), CFrame = CFrame.new(0, 33, 78), Color = towerBrick, Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
	part({ Name = "TowerClockBlock", Size = Vector3.new(15.5, 12, 15.5), CFrame = CFrame.new(0, 44, 78), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "TowerTrim", Size = Vector3.new(16.2, 1.6, 16.2), CFrame = CFrame.new(0, 50.6, 78), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "TowerCap", Size = Vector3.new(12, 4, 12), CFrame = CFrame.new(0, 53.4, 78), Color = Color3.fromRGB(60, 72, 86), Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "TowerSpire", Size = Vector3.new(1.2, 7, 1.2), CFrame = CFrame.new(0, 58.9, 78), Color = Color3.fromRGB(255, 196, 60), Material = Enum.Material.Metal, Parent = parent })
	for _, side in { { normal = Enum.NormalId.Front, cf = CFrame.new(0, 44, 86.0) }, { normal = Enum.NormalId.Back, cf = CFrame.new(0, 44, 70.0) } } do
		local face = part({ Name = "ClockFace", Size = Vector3.new(8, 8, 0.4), CFrame = side.cf, Color = Color3.fromRGB(240, 236, 224), Material = Enum.Material.SmoothPlastic, Parent = parent })
		local hourHand = part({ Name = "ClockHour", Size = Vector3.new(0.6, 2.6, 0.2), CFrame = side.cf * CFrame.new(0, 1.1, side.normal == Enum.NormalId.Front and 0.31 or -0.31), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		local minuteHand = part({ Name = "ClockMinute", Size = Vector3.new(0.5, 3.4, 0.2), CFrame = side.cf * CFrame.new(1.0, 0.6, side.normal == Enum.NormalId.Front and 0.32 or -0.32) * CFrame.Angles(0, 0, math.rad(-55)), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		local _ = hourHand
		local _ = minuteHand
		local ring = Instance.new("SelectionBox")
		ring.Adornee = face
		ring.Color3 = Color3.fromRGB(120, 90, 40)
		ring.LineThickness = 0.06
		ring.Parent = face
	end
end

-- Dormitory: a snug building full of beds. Napping gives a luck buff.
-- Boys and girls dorms share a layout but wear their own accent color.
local function buildDorm(parent: Instance, center: Vector3, name: string, accent: Color3, beds: { BasePart })
	local w, d2 = 70, 60
	buildZone(parent, name:gsub(" ", ""), center, Vector2.new(w, d2), Color3.fromRGB(196, 176, 150), name:upper(), Enum.Material.WoodPlanks)
	-- four walls, door on the side facing campus center (negative Z side)
	local x0, x1 = center.X - w / 2, center.X + w / 2
	local z0, z1 = center.Z - d2 / 2, center.Z + d2 / 2
	buildWallRun(parent, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), { { at = w / 2, width = 14 } })
	buildWallRun(parent, Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), {})
	buildWallRun(parent, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), {})
	buildWallRun(parent, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), {})
	-- accent trim over the door + a name plaque so you can tell whose dorm it is
	part({ Name = "DormTrim", Size = Vector3.new(20, 1.2, 1), CFrame = CFrame.new(center.X, 14.6, z0), Color = accent, Material = Enum.Material.Neon, Parent = parent })
	local plaque = part({ Name = "DormPlaque", Size = Vector3.new(22, 4, 1), CFrame = CFrame.new(center.X, 11.4, z0 - 1.6), Color = Palette.Blackboard, Parent = parent })
	signText(plaque, name:upper(), accent, Enum.NormalId.Front)
	for _, layer in { { inset = -4, y = 17.4 }, { inset = 10, y = 18.9 }, { inset = 24, y = 20.4 } } do
		part({ Name = "DormRoof", Size = Vector3.new(w - layer.inset, 1.5, d2 - layer.inset), CFrame = CFrame.new(center.X, layer.y, center.Z), Color = Color3.fromRGB(122, 78, 64), Material = Enum.Material.ClayRoofTiles, Parent = parent })
	end
	-- warm interior light
	local glow = part({ Name = "DormLight", Size = Vector3.new(1, 0.4, d2 * 0.5), CFrame = CFrame.new(center.X, 14.6, center.Z), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, Parent = parent })
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 38
	light.Color = Color3.fromRGB(255, 234, 190)
	light.Parent = glow
	-- six beds in two rows
	for row = 0, 1 do
		for col = 0, 2 do
			local bx = center.X - 22 + col * 22
			local bz = center.Z - 14 + row * 28
			part({ Name = "BedFrame", Size = Vector3.new(7, 1.6, 12), CFrame = CFrame.new(bx, 0.8, bz), Color = Color3.fromRGB(105, 76, 48), Material = Enum.Material.Wood, Parent = parent })
			local shade = 0.85 + col * 0.12
			local mattress = part({ Name = "DormBed", Size = Vector3.new(6.4, 1, 11), CFrame = CFrame.new(bx, 1.9, bz), Color = Color3.new(math.min(1, accent.R * shade), math.min(1, accent.G * shade), math.min(1, accent.B * shade)), Material = Enum.Material.Fabric, Parent = parent })
			part({ Name = "Pillow", Size = Vector3.new(4.5, 0.8, 2.6), CFrame = CFrame.new(bx, 2.6, bz - 3.8), Color = Color3.fromRGB(240, 240, 232), Material = Enum.Material.Fabric, Parent = parent })
			table.insert(beds, mattress)
		end
	end
end

-- ===== 1:1 reference-art detail pass =========================================
-- Brick academy w/ white trim + castellated towers, furnished interiors,
-- courtyard balconies + lined courts, front lawn with fence and parking.

local WHITE_TRIM = Color3.fromRGB(232, 228, 218)
local BRICK = Color3.fromRGB(126, 78, 62)
local HEDGE = Color3.fromRGB(52, 96, 48)

local function buildCornerTower(parent: Instance, x: number, z: number)
	tag(part({ Name = "CornerTower", Size = Vector3.new(12, 36, 12), CFrame = CFrame.new(x, 18, z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
	part({ Name = "TowerBand", Size = Vector3.new(13, 1.2, 13), CFrame = CFrame.new(x, 34.4, z), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- crenellated top
	for _, offset in { Vector3.new(-4.5, 0, -4.5), Vector3.new(4.5, 0, -4.5), Vector3.new(-4.5, 0, 4.5), Vector3.new(4.5, 0, 4.5), Vector3.new(0, 0, -4.5), Vector3.new(0, 0, 4.5), Vector3.new(-4.5, 0, 0), Vector3.new(4.5, 0, 0) } do
		part({ Name = "Merlon", Size = Vector3.new(2.4, 2.2, 2.4), CFrame = CFrame.new(x + offset.X, 37.1, z + offset.Z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent })
	end
	local shield = part({ Name = "TowerShield", Size = Vector3.new(3.4, 4, 0.4), CFrame = CFrame.new(x, 29, z + (z > 0 and 6.3 or -6.3)), Color = Color3.fromRGB(24, 32, 58), Parent = parent })
	signText(shield, "D", Color3.fromRGB(255, 196, 60), z > 0 and Enum.NormalId.Front or Enum.NormalId.Back)
end

local function buildPortico(parent: Instance, x: number)
	-- white columned entry with a stepped pediment, on the south face
	local z = 86.5
	for i = 0, 3 do
		part({ Name = "PorticoColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(13, 2.0, 2.0), CFrame = CFrame.new(x - 7.5 + i * 5, 6.5, z) * CFrame.Angles(0, 0, math.rad(90)), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "PorticoBeam", Size = Vector3.new(20, 2, 5), CFrame = CFrame.new(x, 14, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PorticoPed1", Size = Vector3.new(16, 1.6, 4.4), CFrame = CFrame.new(x, 15.8, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PorticoPed2", Size = Vector3.new(10, 1.6, 4.0), CFrame = CFrame.new(x, 17.4, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PorticoPed3", Size = Vector3.new(4, 1.6, 3.6), CFrame = CFrame.new(x, 19.0, z - 0.6), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
end

local function buildFrontYard(parent: Instance)
	-- lawns + hedges in the strip between the building and the courtyard
	part({ Name = "FrontLawnWest", Size = Vector3.new(120, 0.35, 22), CFrame = CFrame.new(-85, 0.18, 102), Color = Color3.fromRGB(96, 152, 80), Material = Enum.Material.Grass, Parent = parent })
	part({ Name = "FrontLawnEast", Size = Vector3.new(50, 0.35, 22), CFrame = CFrame.new(50, 0.18, 102), Color = Color3.fromRGB(96, 152, 80), Material = Enum.Material.Grass, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "FrontHedge", Size = Vector3.new(110, 3.2, 2.6), CFrame = CFrame.new(side * 85, 1.6, 91), Color = HEDGE, Material = Enum.Material.Grass, Parent = parent })
	end
	-- short iron fence runs framing the lawns (kept clear of the courtyard)
	for _, run in { { x0 = -140, x1 = -30 }, { x0 = 78, x1 = 145 } } do
		local mid = (run.x0 + run.x1) / 2
		local length = run.x1 - run.x0
		for x = run.x0, run.x1, 14 do
			part({ Name = "FencePier", Size = Vector3.new(2, 5, 2), CFrame = CFrame.new(x, 2.5, 113), Color = BRICK, Material = Enum.Material.Brick, Parent = parent })
		end
		part({ Name = "FenceRail", Size = Vector3.new(length, 0.5, 0.4), CFrame = CFrame.new(mid, 3.9, 113), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "FenceRailLow", Size = Vector3.new(length, 0.5, 0.4), CFrame = CFrame.new(mid, 1.3, 113), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Metal, Parent = parent })
	end
	-- tall cypress pairs flanking the porticos and gates
	for _, x in { -74, -46, 46, 74, -20, 20 } do
		for layer = 0, 2 do
			local w = 3.4 - layer * 0.9
			part({ Name = "Cypress", Size = Vector3.new(w, 4.6, w), CFrame = CFrame.new(x, 2.3 + layer * 4.2, 93.5) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(44, 88, 46), Material = Enum.Material.Grass, Parent = parent })
		end
	end
	-- lampposts lighting the entrance walk
	for _, spot in { Vector3.new(-9, 0, 100), Vector3.new(9, 0, 100), Vector3.new(-9, 0, 128), Vector3.new(9, 0, 128) } do
		part({ Name = "LampPost", Size = Vector3.new(0.7, 9, 0.7), CFrame = CFrame.new(spot.X, 4.5, spot.Z), Color = Color3.fromRGB(34, 38, 44), Material = Enum.Material.Metal, Parent = parent })
		local lamp = part({ Name = "LampHead", Size = Vector3.new(1.5, 1.5, 1.5), CFrame = CFrame.new(spot.X, 9.6, spot.Z), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, Parent = parent })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 234, 190)
		light.Brightness = 1.2
		light.Range = 24
		light.Parent = lamp
	end

	-- parking lot east of the entrance strip
	part({ Name = "ParkingLot", Size = Vector3.new(64, 0.3, 22), CFrame = CFrame.new(110, 0.16, 100), Color = Color3.fromRGB(74, 76, 80), Material = Enum.Material.Asphalt, Parent = parent })
	for i = 0, 5 do
		part({ Name = "ParkingLine", Size = Vector3.new(0.6, 0.32, 10), CFrame = CFrame.new(86 + i * 9, 0.2, 95), Color = Color3.fromRGB(230, 230, 230), Parent = parent })
	end
end

local function detailHallway(parent: Instance)
	-- terrazzo accent tiles down the hallway + water coolers + open lockers
	for i = 0, 7 do
		part({ Name = "TerrazzoTile", Size = Vector3.new(6, 0.22, 6), CFrame = CFrame.new(-140 + i * 40, 0.12, 0), Color = Color3.fromRGB(228, 224, 214), Material = Enum.Material.Marble, Parent = parent })
	end
	for _, x in { -70, 70 } do
		local cooler = part({ Name = "WaterCooler", Size = Vector3.new(1.8, 4, 1.8), CFrame = CFrame.new(x, 2, -12.4), Color = Color3.fromRGB(36, 38, 42), Parent = parent })
		local _ = cooler
		part({ Name = "CoolerJug", Size = Vector3.new(1.4, 1.6, 1.4), CFrame = CFrame.new(x, 4.8, -12.4), Color = Color3.fromRGB(190, 220, 240), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
	end
	-- a few open lockers with shelves + books (reference shot detail)
	for _, spec in { { x = -110, z = 13.2 }, { x = -46, z = -13.2 }, { x = 94, z = 13.2 } } do
		local inward = spec.z > 0 and -1 or 1
		part({ Name = "OpenLockerBox", Size = Vector3.new(2.2, 7.8, 1.4), CFrame = CFrame.new(spec.x, 4.2, spec.z + inward * 0.2), Color = Color3.fromRGB(38, 70, 140), Parent = parent })
		part({ Name = "OpenLockerDoor", Size = Vector3.new(2.1, 7.8, 0.3), CFrame = CFrame.new(spec.x - 1.7, 4.2, spec.z + inward * 1.3) * CFrame.Angles(0, math.rad(inward * 65), 0), Color = Color3.fromRGB(58, 104, 196), Parent = parent })
		for shelf = 0, 1 do
			part({ Name = "LockerShelf", Size = Vector3.new(1.9, 0.2, 1.2), CFrame = CFrame.new(spec.x, 3.2 + shelf * 2.4, spec.z + inward * 0.2), Color = Color3.fromRGB(30, 56, 118), Parent = parent })
			part({ Name = "LockerBook", Size = Vector3.new(0.5, 1.1, 0.9), CFrame = CFrame.new(spec.x - 0.4, 3.9 + shelf * 2.4, spec.z + inward * 0.2), Color = ({ Color3.fromRGB(214, 82, 60), Color3.fromRGB(240, 214, 120) })[shelf + 1], Parent = parent })
		end
	end
end

local function detailCourtyard(parent: Instance)
	-- white court boundary lines
	for _, line in {
		{ size = Vector3.new(34, 0.24, 0.7), cf = CFrame.new(-38, 0.14, 147) },
		{ size = Vector3.new(34, 0.24, 0.7), cf = CFrame.new(-38, 0.14, 169) },
		{ size = Vector3.new(0.7, 0.24, 22), cf = CFrame.new(-55, 0.14, 158) },
		{ size = Vector3.new(0.7, 0.24, 22), cf = CFrame.new(-21, 0.14, 158) },
		{ size = Vector3.new(30, 0.24, 0.7), cf = CFrame.new(40, 0.14, 149.5) },
		{ size = Vector3.new(30, 0.24, 0.7), cf = CFrame.new(40, 0.14, 166.5) },
		{ size = Vector3.new(0.7, 0.24, 17), cf = CFrame.new(25, 0.14, 158) },
		{ size = Vector3.new(0.7, 0.24, 17), cf = CFrame.new(55, 0.14, 158) },
	} do
		part({ Name = "CourtLine", Size = line.size, CFrame = line.cf, Color = Color3.fromRGB(240, 240, 240), Parent = parent })
	end
	-- palm trees flanking the courts
	for _, x in { -14, 14 } do
		for layer = 0, 3 do
			part({ Name = "PalmTrunk", Size = Vector3.new(1.4 - layer * 0.15, 3, 1.4 - layer * 0.15), CFrame = CFrame.new(x + layer * 0.5, 1.5 + layer * 2.8, 176), Color = Color3.fromRGB(140, 104, 76), Material = Enum.Material.Wood, Parent = parent })
		end
		for leaf = 0, 5 do
			local angle = leaf * math.pi / 3
			part({ Name = "PalmLeaf", Size = Vector3.new(6, 0.3, 1.8), CFrame = CFrame.new(x + 1.5 + math.cos(angle) * 2.6, 13, 176 + math.sin(angle) * 2.6) * CFrame.Angles(0, -angle, math.rad(-18)), Color = Color3.fromRGB(64, 132, 60), Material = Enum.Material.Grass, Parent = parent })
		end
	end
	-- balcony walkway over the courtyard face of the main building
	part({ Name = "BalconyFloor", Size = Vector3.new(96, 1, 7), CFrame = CFrame.new(0, 17.2, 89.5), Color = Color3.fromRGB(200, 196, 186), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "BalconyRail", Size = Vector3.new(96, 2.4, 0.5), CFrame = CFrame.new(0, 18.9, 93), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
	for i = 0, 8 do
		if i ~= 4 then -- keep the entrance walk clear
			part({ Name = "BalconyPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 1.4, 1.4), CFrame = CFrame.new(-44 + i * 11, 8.5, 92) * CFrame.Angles(0, 0, math.rad(90)), Color = WHITE_TRIM, Material = Enum.Material.Concrete, Parent = parent })
		end
	end
end

-- The courtyard from the reference render: wrapped on three sides by a
-- two-story colonnade building — open balcony walkway upstairs, flat roof
-- with parapet, flags, and window-textured back walls.
-- Enclosed glazed corridor between two points: floor, walls with a window
-- band, and a flat roof. Turns the scattered rooms into one connected school.
local function buildCorridor(parent: Instance, from: Vector3, to: Vector3, width: number)
	local dir = to - from
	local length = dir.Magnitude
	local unit = dir.Unit
	local mid = from + unit * (length / 2)
	local cf = CFrame.lookAt(mid, to)
	part({ Name = "CorridorFloor", Size = Vector3.new(width, 0.6, length + 2), CFrame = cf * CFrame.new(0, 0.05, 0), Color = Color3.fromRGB(196, 194, 188), Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "CorridorWallLow", Size = Vector3.new(1.4, 4.5, length), CFrame = cf * CFrame.new(side * (width / 2), 2.25, 0), Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent })
		part({ Name = "CorridorGlass", Size = Vector3.new(1.0, 3.6, length), CFrame = cf * CFrame.new(side * (width / 2), 6.3, 0), Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
		part({ Name = "CorridorBand", Size = Vector3.new(1.4, 1.6, length), CFrame = cf * CFrame.new(side * (width / 2), 8.9, 0), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "CorridorRoof", Size = Vector3.new(width + 2.4, 1, length + 2), CFrame = cf * CFrame.new(0, 10.2, 0), Color = Color3.fromRGB(84, 98, 110), Material = Enum.Material.Slate, Parent = parent })
end

local function buildCourtyardWings(parent: Instance)
	local STONE = Color3.fromRGB(196, 200, 206)
	local wings = {
		{ from = Vector3.new(-65, 0, 115), to = Vector3.new(-65, 0, 185), inner = Vector3.new(1, 0, 0), gapAt = 45 },
		{ from = Vector3.new(65, 0, 115), to = Vector3.new(65, 0, 185), inner = Vector3.new(-1, 0, 0), gapAt = 45 },
		{ from = Vector3.new(-65, 0, 190), to = Vector3.new(65, 0, 190), inner = Vector3.new(0, 0, -1), gapAt = -1 },
	}
	for _, wing in wings do
		local dir = (wing.to - wing.from)
		local length = dir.Magnitude
		local unit = dir.Unit
		local mid = wing.from + unit * (length / 2)
		local cf = CFrame.lookAt(mid, mid + wing.inner)
		-- back wall (two stories of window texture; split around the walk-through gap)
		local segments: { { number } } = if wing.gapAt >= 0
			then { { 0, wing.gapAt - 9 }, { wing.gapAt + 9, length } }
			else { { 0, length } }
		for _, seg in segments do
			local segLen2 = seg[2] - seg[1]
			if segLen2 > 1 then
				local segMid = wing.from + unit * ((seg[1] + seg[2]) / 2)
				local segCf = CFrame.lookAt(segMid, segMid + wing.inner)
				tag(part({ Name = "WingBackLow", Size = Vector3.new(segLen2, 10, 1.6), CFrame = segCf * CFrame.new(0, 5, -8) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(105, 118, 138), Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
			end
		end
		tag(part({ Name = "WingBackHigh", Size = Vector3.new(length, 9, 1.6), CFrame = cf * CFrame.new(0, 15, -8) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(105, 118, 138), Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
		-- second-floor balcony slab + railing
		part({ Name = "WingBalcony", Size = Vector3.new(length, 1, 9), CFrame = cf * CFrame.new(0, 10.2, -3.5) * CFrame.Angles(0, math.rad(90), 0), Color = STONE, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "WingRailTop", Size = Vector3.new(length, 0.5, 0.5), CFrame = cf * CFrame.new(0, 13.4, 0.6) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(235, 235, 235), Parent = parent })
		part({ Name = "WingRailPanel", Size = Vector3.new(length, 2.2, 0.25), CFrame = cf * CFrame.new(0, 12.2, 0.6) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(210, 214, 220), Transparency = 0.25, Parent = parent })
		-- flat roof + parapet
		part({ Name = "WingTopRoof", Size = Vector3.new(length + 2, 1, 11), CFrame = cf * CFrame.new(0, 20.2, -3) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(154, 158, 164), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "WingTopParapet", Size = Vector3.new(length + 2, 1.6, 0.6), CFrame = cf * CFrame.new(0, 21.3, 2.2) * CFrame.Angles(0, math.rad(90), 0), Color = STONE, Parent = parent })
		-- ground colonnade (cylindrical columns on the courtyard side)
		local count = math.floor(length / 10)
		for i = 0, count do
			local at = i * (length / count)
			if wing.gapAt < 0 or math.abs(at - wing.gapAt) > 9 then
				part({ Name = "WingColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 1.6, 1.6), CFrame = CFrame.lookAt(wing.from + unit * at, wing.from + unit * at + wing.inner) * CFrame.new(0, 5, 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Concrete, Parent = parent })
			end
		end
		-- upper-floor columns matching the rhythm
		for i = 0, count do
			local at = i * (length / count)
			part({ Name = "WingColumnUp", Size = Vector3.new(1.2, 9, 1.2), CFrame = CFrame.lookAt(wing.from + unit * at, wing.from + unit * at + wing.inner) * CFrame.new(0, 15.5, -7.4), Color = STONE, Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	-- flags on the south wing roof
	local flagColors = { Color3.fromRGB(232, 76, 76), Color3.fromRGB(255, 196, 60), Color3.fromRGB(64, 140, 226), Color3.fromRGB(74, 160, 90) }
	for i = 0, 3 do
		local x = -45 + i * 30
		part({ Name = "RoofFlagPole", Size = Vector3.new(0.5, 8, 0.5), CFrame = CFrame.new(x, 24.7, 190), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "RoofFlag", Size = Vector3.new(4, 2.4, 0.2), CFrame = CFrame.new(x + 2.2, 27.4, 190), Color = flagColors[i + 1], Parent = parent })
	end
	-- raised stone viewing platform with steps on the west edge (reference left side)
	part({ Name = "CourtPlatform", Size = Vector3.new(16, 3, 26), CFrame = CFrame.new(-52, 1.5, 128), Color = Color3.fromRGB(178, 182, 188), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "CourtSteps1", Size = Vector3.new(4, 1, 26), CFrame = CFrame.new(-42, 0.5, 128), Color = Color3.fromRGB(190, 194, 200), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "CourtSteps2", Size = Vector3.new(4, 2, 26), CFrame = CFrame.new(-46, 1.0, 128), Color = Color3.fromRGB(184, 188, 194), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "PlatformRail", Size = Vector3.new(0.5, 3, 26), CFrame = CFrame.new(-59.7, 4.5, 128), Color = Color3.fromRGB(235, 235, 235), Parent = parent })
	-- extra bunting: two diagonal lines like the render
	for _, spec in {
		{ from = Vector3.new(-58, 18, 120), to = Vector3.new(58, 15, 150) },
		{ from = Vector3.new(-58, 15, 178), to = Vector3.new(58, 18, 152) },
	} do
		local dirv = spec.to - spec.from
		local lineMid = spec.from + dirv * 0.5
		local lineCf = CFrame.lookAt(lineMid, spec.to)
		part({ Name = "BuntingLineDiag", Size = Vector3.new(0.15, 0.15, dirv.Magnitude), CFrame = lineCf, Color = Color3.fromRGB(220, 220, 220), Parent = parent })
		local flagColors2 = { Color3.fromRGB(232, 76, 76), Color3.fromRGB(255, 196, 60), Color3.fromRGB(74, 160, 90), Color3.fromRGB(64, 140, 226), Color3.fromRGB(168, 90, 220) }
		for i = 1, 12 do
			local alpha = i / 13
			local pos = spec.from + dirv * alpha
			part({ Name = "BuntingFlagDiag", Size = Vector3.new(1.2, 1.5, 0.14), CFrame = CFrame.new(pos - Vector3.new(0, 0.9, 0)), Color = flagColors2[(i % #flagColors2) + 1], Parent = parent })
		end
	end
end

local function furnishClassroom(parent: Instance)
	local c = Vector3.new(0, 0, -150)
	-- whiteboards on the far wall
	for _, x in { -18, 6 } do
		part({ Name = "Whiteboard", Size = Vector3.new(20, 8, 0.5), CFrame = CFrame.new(c.X + x + 6, 7, c.Z - 28), Color = Color3.fromRGB(244, 244, 244), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "BoardFrame", Size = Vector3.new(21, 0.8, 0.6), CFrame = CFrame.new(c.X + x + 6, 2.8, c.Z - 28), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = parent })
	end
	-- corkboards + bookshelf on the side wall
	part({ Name = "Corkboard", Size = Vector3.new(0.5, 6, 10), CFrame = CFrame.new(c.X + 38, 7, c.Z + 6), Color = Color3.fromRGB(196, 156, 108), Parent = parent })
	part({ Name = "Bookshelf", Size = Vector3.new(1.6, 9, 14), CFrame = CFrame.new(c.X + 38.5, 4.5, c.Z - 12), Color = Color3.fromRGB(140, 104, 76), Material = Enum.Material.Wood, Parent = parent })
	for row = 0, 2 do
		for slot = 0, 4 do
			part({ Name = "ShelfBook", Size = Vector3.new(1.0, 1.6, 1.6), CFrame = CFrame.new(c.X + 38.3, 2.4 + row * 2.6, c.Z - 17.5 + slot * 2.6), Color = ({ Color3.fromRGB(214, 82, 60), Color3.fromRGB(90, 140, 200), Color3.fromRGB(110, 180, 110), Color3.fromRGB(240, 214, 120), Color3.fromRGB(168, 90, 220) })[slot + 1], Parent = parent })
		end
	end
	-- desks + blue chairs in rows
	for row = 0, 1 do
		for col = 0, 3 do
			local dx, dz = c.X - 24 + col * 14, c.Z - 8 + row * 14
			part({ Name = "DeskTop", Size = Vector3.new(8, 0.5, 4), CFrame = CFrame.new(dx, 3.4, dz), Color = Color3.fromRGB(214, 200, 176), Material = Enum.Material.WoodPlanks, Parent = parent })
			for _, leg in { { -3.5, -1.5 }, { 3.5, -1.5 }, { -3.5, 1.5 }, { 3.5, 1.5 } } do
				part({ Name = "DeskLeg", Size = Vector3.new(0.4, 3.2, 0.4), CFrame = CFrame.new(dx + leg[1], 1.6, dz + leg[2]), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = parent })
			end
			part({ Name = "ChairSeat", Size = Vector3.new(2.6, 0.4, 2.4), CFrame = CFrame.new(dx, 2.2, dz + 3.4), Color = Color3.fromRGB(58, 104, 196), Parent = parent })
			part({ Name = "ChairBack", Size = Vector3.new(2.6, 2.6, 0.4), CFrame = CFrame.new(dx, 3.7, dz + 4.5), Color = Color3.fromRGB(58, 104, 196), Parent = parent })
		end
	end
	-- drop-ceiling: full grid texture + glowing panels
	tag(part({ Name = "ClassCeiling", Size = Vector3.new(78, 0.6, 58), CFrame = CFrame.new(c.X, 14.2, c.Z), Color = Color3.fromRGB(238, 234, 224), Parent = parent }), "TexCeiling")
	for _, x in { -20, 8 } do
		for _, z in { -14, 2 } do
			part({ Name = "CeilingPanel", Size = Vector3.new(10, 0.3, 4), CFrame = CFrame.new(c.X + x, 13.6, c.Z + z), Color = Color3.fromRGB(250, 250, 240), Material = Enum.Material.Neon, Parent = parent })
		end
	end
	-- salmon feature walls like the reference classroom
	part({ Name = "ClassWallSalmon", Size = Vector3.new(0.8, 13, 56), CFrame = CFrame.new(c.X + 39.2, 7, c.Z), Color = Color3.fromRGB(205, 122, 92), Parent = parent })
	part({ Name = "ClassWallSalmon2", Size = Vector3.new(24, 13, 0.8), CFrame = CFrame.new(c.X + 27, 7, c.Z - 29.2), Color = Color3.fromRGB(205, 122, 92), Parent = parent })
end

local function furnishCafeteria(parent: Instance)
	local c = Vector3.new(-215, 0, 60)
	-- warm accent wall panels
	for _, z in { c.Z - 33, c.Z + 33 } do
		part({ Name = "CafeAccent", Size = Vector3.new(66, 8, 0.6), CFrame = CFrame.new(c.X, 6, z), Color = Color3.fromRGB(226, 148, 62), Parent = parent })
	end
	-- neon rectangle light overhead
	for _, spec in {
		{ size = Vector3.new(18, 0.4, 0.8), cf = CFrame.new(c.X, 13.4, c.Z - 5) },
		{ size = Vector3.new(18, 0.4, 0.8), cf = CFrame.new(c.X, 13.4, c.Z + 5) },
		{ size = Vector3.new(0.8, 0.4, 10), cf = CFrame.new(c.X - 9, 13.4, c.Z) },
		{ size = Vector3.new(0.8, 0.4, 10), cf = CFrame.new(c.X + 9, 13.4, c.Z) },
	} do
		part({ Name = "CafeNeon", Size = spec.size, CFrame = spec.cf, Color = Color3.fromRGB(255, 244, 214), Material = Enum.Material.Neon, Parent = parent })
	end
	-- painted queue squares on the floor
	for i = 0, 4 do
		part({ Name = "QueueSquare", Size = Vector3.new(4.4, 0.22, 4.4), CFrame = CFrame.new(c.X - 22 + i * 6, 0.13, c.Z + 26), Color = Color3.fromRGB(240, 240, 240), Transparency = 0.35, Parent = parent })
	end
end

local function detailGym(parent: Instance)
	local c = Vector3.new(215, 0, 60)
	-- red/white pennant stripe around the top of the walls
	for i = 0, 15 do
		part({ Name = "GymStripe", Size = Vector3.new(4.2, 2.2, 0.4), CFrame = CFrame.new(c.X - 32 + i * 4.3, 12.5, c.Z - 33.6), Color = i % 2 == 0 and Color3.fromRGB(196, 44, 44) or Color3.fromRGB(240, 240, 240), Parent = parent })
	end
	-- high window band
	part({ Name = "GymWindowBand", Size = Vector3.new(50, 3.2, 0.5), CFrame = CFrame.new(c.X, 10, c.Z + 33.6), Color = Color3.fromRGB(200, 224, 240), Material = Enum.Material.Glass, Transparency = 0.4, Parent = parent })
	-- basketball hoop on the gym wall
	part({ Name = "GymBoard", Size = Vector3.new(6, 4, 0.4), CFrame = CFrame.new(c.X, 9.6, c.Z - 32.8), Color = Color3.fromRGB(240, 240, 240), Parent = parent })
	part({ Name = "GymRim", Size = Vector3.new(1.6, 0.3, 1.6), CFrame = CFrame.new(c.X, 8.2, c.Z - 31.6), Color = Color3.fromRGB(226, 100, 60), Material = Enum.Material.Neon, Parent = parent })
end

function MapService.Build(): Map
	local folder = Instance.new("Folder")
	folder.Name = "CrumbworthHigh"

	buildTerrain()

	-- solid interior base floor: no terrain grass inside the school
	tag(part({
		Name = "SchoolBaseFloor",
		Size = Vector3.new(336, 1, 168),
		CFrame = CFrame.new(0, -0.55, 0),
		Color = Color3.fromRGB(196, 194, 188),
		Parent = folder,
	}), "TexFloorTile")

	-- hallway (the conveyor) along the X axis
	tag(part({
		Name = "HallwayFloor",
		Size = Vector3.new(320, 1, 28),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(196, 194, 188),
		Parent = folder,
	}), "TexFloorTile")
	part({
		Name = "HallwayStripe",
		Size = Vector3.new(320, 0.2, 3),
		CFrame = CFrame.new(0, 0.11, 0),
		Color = Palette.BusYellow,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	for _, xEnd in { -160, 160 } do
		local sign = part({
			Name = "HallwaySign",
			Size = Vector3.new(2, 6, 24),
			CFrame = CFrame.new(xEnd, 8, 0),
			Color = Palette.Blackboard,
			Parent = folder,
		})
		signText(sign, "MAIN HALLWAY", Palette.BusYellow, Enum.NormalId.Left)
		signText(sign, "MAIN HALLWAY", Palette.BusYellow, Enum.NormalId.Right)
	end

	-- navy locker banks lining both hallway walls (reference-look lockers)
	for _, zSide in { -13.2, 13.2 } do
		for _, bankX in { -130, -90, -50, 50, 90, 130 } do
			tag(part({
				Name = "LockerBank",
				Size = Vector3.new(24, 8.4, 1.6),
				CFrame = CFrame.new(bankX, 4.2, zSide),
				Color = Color3.fromRGB(46, 84, 168),
				Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			}), "TexLocker")
		end
	end

	-- 8 homeroom plots: 4 above the hallway, 4 below
	local plots: { Plot } = {}
	local xs = { -117, -39, 39, 117 }
	for i, x in xs do
		-- top row: plot sits at negative z, front faces +Z (toward hallway)
		local centerTop = Vector3.new(x, 0, -52)
		table.insert(plots, buildPlot(i, CFrame.lookAt(centerTop, centerTop + Vector3.new(0, 0, 1)), folder))
	end
	for i, x in xs do
		local centerBottom = Vector3.new(x, 0, 52)
		table.insert(plots, buildPlot(4 + i, CFrame.lookAt(centerBottom, centerBottom + Vector3.new(0, 0, -1)), folder))
	end

	-- surrounding zones
	buildZone(folder, "Cafeteria", Vector3.new(-215, 0, 60), Vector2.new(70, 70), Color3.fromRGB(235, 214, 156), "CAFETERIA", Enum.Material.CeramicTiles)
	buildZone(folder, "PrincipalsOffice", Vector3.new(-215, 0, -60), Vector2.new(70, 70), Color3.fromRGB(214, 226, 235), "PRINCIPAL'S OFFICE\n(THE STORE)", Enum.Material.Marble)
	buildZone(folder, "Gym", Vector3.new(215, 0, 60), Vector2.new(70, 70), Color3.fromRGB(210, 160, 110), "GYM — FIGHT ZONE", Enum.Material.WoodPlanks)
	local trophyFloor = buildZone(folder, "TrophyHall", Vector3.new(215, 0, -60), Vector2.new(70, 70), Color3.fromRGB(228, 228, 228), "TROPHY HALL", Enum.Material.Marble)
	tag(buildZone(folder, "Courtyard", Vector3.new(0, 0, 150), Vector2.new(120, 70), Color3.fromRGB(134, 138, 159), "COURTYARD — CLIQUES", Enum.Material.Concrete), "TexGround")
	tag(buildZone(folder, "Classroom101", Vector3.new(0, 0, -150), Vector2.new(80, 60), Color3.fromRGB(148, 118, 96), "CLASSROOM 101\nPOP QUIZ", Enum.Material.Carpet), "TexCarpet")

	-- trophy hall boards
	local trophyCashBoard = part({
		Name = "TrophyCashBoard",
		Size = Vector3.new(24, 18, 1),
		CFrame = CFrame.new(215 - 14, 9, -92),
		Color = Palette.Blackboard,
		Parent = folder,
	})
	local trophyAuraBoard = part({
		Name = "TrophyAuraBoard",
		Size = Vector3.new(24, 18, 1),
		CFrame = CFrame.new(215 + 14, 9, -92),
		Color = Palette.Blackboard,
		Parent = folder,
	})

	-- clique boards in the courtyard
	local Cliques = require(ReplicatedStorage.Config.Cliques)
	local cliqueBoards: { [string]: BasePart } = {}
	for i, clique in Cliques.List do
		local board = part({
			Name = "CliqueBoard_" .. clique.id,
			Size = Vector3.new(13, 8, 1),
			CFrame = CFrame.new(-45 + (i - 1) * 30, 4.5, 183),
			Color = clique.color,
			Parent = folder,
		})
		signText(board, clique.name:upper() .. "\n" .. clique.motto, Palette.White, Enum.NormalId.Front)
		signText(board, clique.name:upper(), Palette.White, Enum.NormalId.Back)
		cliqueBoards[clique.id] = board
	end

	-- decorations
	buildBus(folder, CFrame.new(-120, 0, 120) * CFrame.Angles(0, math.rad(15), 0))
	buildHallwayLights(folder)
	buildBenches(folder)
	buildCafeteriaTables(folder, Vector3.new(-215, 0, 60))
	buildGymMarkings(folder, Vector3.new(215, 0, 60))
	buildStatues(folder)
	buildPerimeter(folder)
	buildZoneWalls(folder, Vector3.new(-215, 0, 60), Vector2.new(70, 70), Vector3.new(1, 0, 0))
	buildZoneWalls(folder, Vector3.new(-215, 0, -60), Vector2.new(70, 70), Vector3.new(1, 0, 0))
	buildZoneWalls(folder, Vector3.new(215, 0, 60), Vector2.new(70, 70), Vector3.new(-1, 0, 0))
	buildZoneWalls(folder, Vector3.new(215, 0, -60), Vector2.new(70, 70), Vector3.new(-1, 0, 0))
	buildZoneWalls(folder, Vector3.new(0, 0, -150), Vector2.new(80, 60), Vector3.new(0, 0, 1))
	buildRoof(folder, Vector3.new(-215, 0, 60), Vector2.new(70, 70))
	buildRoof(folder, Vector3.new(-215, 0, -60), Vector2.new(70, 70))
	buildRoof(folder, Vector3.new(215, 0, 60), Vector2.new(70, 70))
	buildRoof(folder, Vector3.new(215, 0, -60), Vector2.new(70, 70))
	buildRoof(folder, Vector3.new(0, 0, -150), Vector2.new(80, 60))
	-- walkways stitching the campus together
	buildPath(folder, Vector3.new(-160, 0, 0), Vector3.new(-180, 0, 60), 8)
	buildPath(folder, Vector3.new(-160, 0, 0), Vector3.new(-180, 0, -60), 8)
	buildPath(folder, Vector3.new(160, 0, 0), Vector3.new(180, 0, 60), 8)
	buildPath(folder, Vector3.new(160, 0, 0), Vector3.new(180, 0, -60), 8)
	buildPath(folder, Vector3.new(0, 0, 30), Vector3.new(0, 0, 115), 10)
	buildPath(folder, Vector3.new(0, 0, -30), Vector3.new(0, 0, -120), 8)
	-- courtyard sports courts + festival bunting (reference-look campus yard)
	local courtBase = part({ Name = "BasketballCourt", Size = Vector3.new(34, 0.2, 22), CFrame = CFrame.new(-38, 0.11, 158), Color = Color3.fromRGB(52, 118, 190), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local _ = courtBase
	part({ Name = "CourtKey", Size = Vector3.new(10, 0.22, 22), CFrame = CFrame.new(-38, 0.12, 158), Color = Color3.fromRGB(226, 130, 62), Material = Enum.Material.SmoothPlastic, Parent = folder })
	for _, hoopX in { -54, -22 } do
		part({ Name = "HoopPost", Size = Vector3.new(0.8, 11, 0.8), CFrame = CFrame.new(hoopX, 5.5, 158), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = folder })
		part({ Name = "HoopBoard", Size = Vector3.new(0.4, 4, 6), CFrame = CFrame.new(hoopX + (hoopX < -38 and 0.7 or -0.7), 9.6, 158), Color = Color3.fromRGB(240, 240, 240), Parent = folder })
		part({ Name = "HoopRim", Size = Vector3.new(1.6, 0.3, 1.6), CFrame = CFrame.new(hoopX + (hoopX < -38 and 1.8 or -1.8), 8.2, 158), Color = Color3.fromRGB(226, 100, 60), Material = Enum.Material.Neon, Parent = folder })
	end
	local volleyBase = part({ Name = "VolleyballCourt", Size = Vector3.new(30, 0.2, 18), CFrame = CFrame.new(40, 0.11, 158), Color = Color3.fromRGB(226, 148, 168), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local _2 = volleyBase
	for _, postZ in { 149.5, 166.5 } do
		part({ Name = "NetPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(40, 4, postZ), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = folder })
	end
	part({ Name = "VolleyNet", Size = Vector3.new(0.2, 2.4, 17), CFrame = CFrame.new(40, 6.4, 158), Color = Color3.fromRGB(235, 235, 235), Material = Enum.Material.Fabric, Transparency = 0.35, Parent = folder })
	-- bunting strings across the courtyard: poles, a visible line, hanging flags
	local buntingColors = { Color3.fromRGB(232, 76, 76), Color3.fromRGB(255, 196, 60), Color3.fromRGB(74, 160, 90), Color3.fromRGB(64, 140, 226), Color3.fromRGB(168, 90, 220) }
	for line = 0, 1 do
		local z = 132 + line * 36
		for _, px in { -58, 58 } do
			part({ Name = "BuntingPole", Size = Vector3.new(0.7, 14, 0.7), CFrame = CFrame.new(px, 7, z), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = folder })
		end
		part({ Name = "BuntingLine", Size = Vector3.new(116, 0.18, 0.18), CFrame = CFrame.new(0, 13.6, z), Color = Color3.fromRGB(220, 220, 220), Parent = folder })
		for i = 0, 14 do
			local x = -52 + i * 7.5
			part({
				Name = "BuntingFlag",
				Size = Vector3.new(1.4, 1.7, 0.15),
				CFrame = CFrame.new(x, 12.6, z) * CFrame.Angles(math.rad(8), 0, 0),
				Color = buntingColors[(i % #buntingColors) + 1],
				Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			})
		end
	end

	buildFountain(folder, Vector3.new(0, 0, 122))
	buildBanners(folder)
	buildMainShell(folder)
	buildCornerTower(folder, -168, -84)
	buildCornerTower(folder, 168, -84)
	buildCornerTower(folder, -168, 84)
	buildCornerTower(folder, 168, 84)
	buildPortico(folder, -60)
	buildPortico(folder, 60)
	buildFrontYard(folder)
	detailHallway(folder)
	for _, zRow in { -8, 8 } do
		for i = 0, 19 do
			part({ Name = "CeilingDot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), CFrame = CFrame.new(-152 + i * 16, 26.0, zRow) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 248, 230), Material = Enum.Material.Neon, Parent = folder })
		end
	end
	detailCourtyard(folder)
	-- every outbuilding gets a real front wall with a doorway...
	buildWallRun(folder, Vector3.new(-180, 0, 25), Vector3.new(-180, 0, 95), { { at = 35, width = 14 } }) -- cafeteria front
	buildWallRun(folder, Vector3.new(-180, 0, -95), Vector3.new(-180, 0, -25), { { at = 35, width = 14 } }) -- principal front
	buildWallRun(folder, Vector3.new(180, 0, 25), Vector3.new(180, 0, 95), { { at = 35, width = 14 } }) -- gym front
	buildWallRun(folder, Vector3.new(180, 0, -95), Vector3.new(180, 0, -25), { { at = 35, width = 14 } }) -- trophy front
	buildWallRun(folder, Vector3.new(-40, 0, -120), Vector3.new(40, 0, -120), { { at = 40, width = 16 } }) -- classroom front
	-- ...and an enclosed corridor tying it into the main building
	buildCorridor(folder, Vector3.new(-167, 0, 0), Vector3.new(-181, 0, 60), 10)
	buildCorridor(folder, Vector3.new(-167, 0, 0), Vector3.new(-181, 0, -60), 10)
	buildCorridor(folder, Vector3.new(167, 0, 0), Vector3.new(181, 0, 60), 10)
	buildCorridor(folder, Vector3.new(167, 0, 0), Vector3.new(181, 0, -60), 10)
	buildCorridor(folder, Vector3.new(0, 0, -85), Vector3.new(0, 0, -121), 12)
	buildCourtyardWings(folder)
	furnishClassroom(folder)
	furnishCafeteria(folder)
	detailGym(folder)
	local dormBeds: { BasePart } = {}
	buildDorm(folder, Vector3.new(-195, 0, 200), "Boys Dorm", Color3.fromRGB(70, 130, 220), dormBeds)
	buildDorm(folder, Vector3.new(195, 0, 200), "Girls Dorm", Color3.fromRGB(232, 110, 170), dormBeds)
	buildPath(folder, Vector3.new(-60, 0, 150), Vector3.new(-170, 0, 195), 8)
	buildPath(folder, Vector3.new(60, 0, 150), Vector3.new(170, 0, 195), 8)

	-- detention room: where curfew-breakers get dragged after dark
	local detentionCenter = Vector3.new(-100, 0, -210)
	buildZone(folder, "Detention", detentionCenter, Vector2.new(36, 28), Color3.fromRGB(126, 126, 132), "DETENTION", Enum.Material.Concrete)
	do
		local dx0, dx1 = detentionCenter.X - 18, detentionCenter.X + 18
		local dz0, dz1 = detentionCenter.Z - 14, detentionCenter.Z + 14
		buildWallRun(folder, Vector3.new(dx0, 0, dz0), Vector3.new(dx1, 0, dz0), {})
		buildWallRun(folder, Vector3.new(dx0, 0, dz1), Vector3.new(dx1, 0, dz1), { { at = 18, width = 10 } })
		buildWallRun(folder, Vector3.new(dx0, 0, dz0), Vector3.new(dx0, 0, dz1), {})
		buildWallRun(folder, Vector3.new(dx1, 0, dz0), Vector3.new(dx1, 0, dz1), {})
		part({ Name = "DetentionRoof", Size = Vector3.new(40, 1.4, 32), CFrame = CFrame.new(detentionCenter.X, 16.8, detentionCenter.Z), Color = Color3.fromRGB(84, 98, 110), Material = Enum.Material.Slate, Parent = folder })
	end
	buildPath(folder, Vector3.new(-40, 0, -150), Vector3.new(-95, 0, -195), 6)
	buildEntranceArch(folder)
	buildFlagpole(folder)
	buildHoops(folder, Vector3.new(215, 0, 60))
	buildRoad(folder)
	buildCanopy(folder)
	buildProps(folder)
	buildTreeline(folder, buildTree)
	buildCheckerFloor(folder, Vector3.new(-215, 0, 60), Vector2.new(70, 70))
	buildLeaves(folder, Vector3.new(0, 0, 150))
	for _, pos in { Vector3.new(-34, 0, 96), Vector3.new(34, 0, 96), Vector3.new(-60, 0, 130), Vector3.new(60, 0, 130) } do
		buildFlowerbed(folder, pos)
	end
	for _, pos in {
		Vector3.new(-40, 0, 130), Vector3.new(45, 0, 128), Vector3.new(-15, 0, 172),
		Vector3.new(30, 0, 175), Vector3.new(-52, 0, 168), Vector3.new(55, 0, 150),
	} do
		buildTree(folder, pos, 1 + (pos.X % 3) * 0.15)
	end

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 22)
	spawn.Anchored = true
	spawn.Color = Palette.BusYellow
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Name = "BusStop"
	spawn.Parent = folder

	folder.Parent = workspace

	local _ = trophyFloor

	return {
		plots = plots,
		conveyorStart = Vector3.new(-150, 0, 0),
		conveyorEnd = Vector3.new(150, 0, 0),
		trophyCashBoard = trophyCashBoard,
		trophyAuraBoard = trophyAuraBoard,
		cliqueBoards = cliqueBoards,
		dormBeds = dormBeds,
		detentionSpot = detentionCenter,
		folder = folder,
	}
end

-- Is a world position inside the plot's footprint (with a little slack)?
function MapService.IsInsidePlot(plot: Plot, position: Vector3): boolean
	local localPos = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= plot.halfSize.X + 2
		and math.abs(localPos.Z) <= plot.halfSize.Y + 2
		and localPos.Y < 30
end

local _ = GameConfig -- (kept for future map knobs)

return MapService
