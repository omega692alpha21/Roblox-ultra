--!strict
-- Generates all of Crumbworth High from parts at server start. No Studio assets needed.
-- Returns handles to everything other services attach behavior to.

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
	-- locker detail stripes
	for i = 1, 7 do
		part({
			Name = "LockerSeam",
			Size = Vector3.new(0.4, 9, 0.4),
			CFrame = cf * CFrame.new(-24 + i * 6, 4.5, -(depth / 2 - 2.2)),
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
	pileBillboard.Size = UDim2.fromOffset(220, 60)
	pileBillboard.StudsOffset = Vector3.new(0, 6, 0)
	pileBillboard.AlwaysOnTop = true
	pileBillboard.MaxDistance = 220
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

local function buildZone(parent: Instance, name: string, center: Vector3, size: Vector2, color: Color3, label: string): BasePart
	local floor = part({
		Name = name .. "Floor",
		Size = Vector3.new(size.X, 1, size.Y),
		CFrame = CFrame.new(center) * CFrame.new(0, -0.5, 0),
		Color = color,
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
		Color = Color3.fromRGB(226, 178, 172),
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

function MapService.Build(): Map
	local folder = Instance.new("Folder")
	folder.Name = "CrumbworthHigh"

	-- ground
	part({
		Name = "Ground",
		Size = Vector3.new(560, 2, 560),
		CFrame = CFrame.new(0, -1.5, 0),
		Color = Color3.fromRGB(116, 158, 96),
		Material = Enum.Material.Grass,
		Parent = folder,
	})

	-- hallway (the conveyor) along the X axis
	part({
		Name = "HallwayFloor",
		Size = Vector3.new(320, 1, 28),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = Palette.Floor,
		Parent = folder,
	})
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
	buildZone(folder, "Cafeteria", Vector3.new(-215, 0, 60), Vector2.new(70, 70), Color3.fromRGB(235, 214, 156), "CAFETERIA")
	buildZone(folder, "PrincipalsOffice", Vector3.new(-215, 0, -60), Vector2.new(70, 70), Color3.fromRGB(214, 226, 235), "PRINCIPAL'S OFFICE\n(THE STORE)")
	buildZone(folder, "Gym", Vector3.new(215, 0, 60), Vector2.new(70, 70), Color3.fromRGB(226, 178, 172), "GYM — FIGHT ZONE")
	local trophyFloor = buildZone(folder, "TrophyHall", Vector3.new(215, 0, -60), Vector2.new(70, 70), Color3.fromRGB(228, 228, 228), "TROPHY HALL")
	buildZone(folder, "Courtyard", Vector3.new(0, 0, 150), Vector2.new(120, 70), Color3.fromRGB(148, 190, 128), "COURTYARD — CLIQUES")
	buildZone(folder, "Classroom101", Vector3.new(0, 0, -150), Vector2.new(80, 60), Color3.fromRGB(199, 210, 232), "CLASSROOM 101\nPOP QUIZ")

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
			Size = Vector3.new(18, 12, 1),
			CFrame = CFrame.new(-45 + (i - 1) * 30, 6, 182),
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
