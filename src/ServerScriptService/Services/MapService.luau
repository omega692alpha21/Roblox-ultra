--!strict
-- Generates all of Crumbworth High from parts at server start. No Studio assets needed.
-- Returns handles to everything other services attach behavior to.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local PropSizes = require(ReplicatedStorage.Config.PropSizes)

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
	trim: { TrimRun },
	props: { PropRequest },
	library: Vector3,
	tennis: Vector3,
	pool: Vector3,
	conveyorStart: Vector3,
	conveyorEnd: Vector3,
	trophyCashBoard: BasePart,
	trophyAuraBoard: BasePart,
	cliqueBoards: { [string]: BasePart },
	dormBeds: { BasePart },
	detentionSpot: Vector3,
	infirmary: Vector3,
	secretDoor: BasePart,
	sanctumSpawn: Vector3,
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

-- A courtyard lab annex: a glass-walled pavilion with an open south side, so
-- the science subjects get real rooms without cutting new space out of a
-- floor plan that is already full.
local function buildPavilion(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector2,
	label: string,
	accent: Color3,
	glass: Color3
)
	local half = Vector2.new(size.X / 2, size.Y / 2)
	part({
		Name = name .. "Floor",
		Size = Vector3.new(size.X, 1, size.Y),
		CFrame = CFrame.new(center) * CFrame.new(0, -0.4, 0),
		Color = Color3.fromRGB(226, 226, 222),
		Material = Enum.Material.CeramicTiles,
		Parent = parent,
	})
	-- three glass walls; the fourth side is the way in
	local walls = {
		{ pos = Vector3.new(0, 7, -half.Y), size = Vector3.new(size.X, 14, 1) },
		{ pos = Vector3.new(-half.X, 7, 0), size = Vector3.new(1, 14, size.Y) },
		{ pos = Vector3.new(half.X, 7, 0), size = Vector3.new(1, 14, size.Y) },
	}
	for i, wall in walls do
		local pane = part({
			Name = name .. "Glass" .. i,
			Size = wall.size,
			CFrame = CFrame.new(center) * CFrame.new(wall.pos),
			Color = glass,
			Material = Enum.Material.Glass,
			Transparency = 0.62,
			Parent = parent,
		})
		pane.Reflectance = 0.08
	end
	-- frame posts at the corners and either side of the opening
	for _, corner in { Vector3.new(-half.X, 0, -half.Y), Vector3.new(half.X, 0, -half.Y), Vector3.new(-half.X, 0, half.Y), Vector3.new(half.X, 0, half.Y) } do
		part({
			Name = name .. "Post",
			Size = Vector3.new(1.6, 15, 1.6),
			CFrame = CFrame.new(center) * CFrame.new(corner + Vector3.new(0, 7.5, 0)),
			Color = accent,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
	-- lintel over the open side, so it reads as a doorway and not a missing wall
	part({
		Name = name .. "Lintel",
		Size = Vector3.new(size.X, 2, 1.6),
		CFrame = CFrame.new(center) * CFrame.new(0, 14, half.Y),
		Color = accent,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local roof = part({
		Name = name .. "Roof",
		Size = Vector3.new(size.X + 2, 0.8, size.Y + 2),
		CFrame = CFrame.new(center) * CFrame.new(0, 15.2, 0),
		Color = glass,
		Material = Enum.Material.Glass,
		Transparency = 0.5,
		Parent = parent,
	})
	roof.Reflectance = 0.12
	-- benches down both sides: this is a lab, not an empty box
	for _, bx in { -half.X + 5, half.X - 5 } do
		part({
			Name = name .. "Bench",
			Size = Vector3.new(5, 3.2, size.Y - 10),
			CFrame = CFrame.new(center) * CFrame.new(bx, 1.6, 0),
			Color = Color3.fromRGB(64, 78, 74),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	local sign = part({
		Name = name .. "Sign",
		Size = Vector3.new(size.X - 6, 4, 0.6),
		CFrame = CFrame.new(center) * CFrame.new(0, 17.6, half.Y),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(sign, label, accent, Enum.NormalId.Front)
	signText(sign, label, accent, Enum.NormalId.Back)
end

-- ===== campus grounds: the three places that are not the school building =====
--
-- The floor plan is full, so these sit outside it: the library on the north
-- quad behind the gym, the tennis stadium east, the pool west. Paths run back
-- to the building so they read as part of the campus and not as scenery
-- dropped on a lawn.

local function buildCampusPath(parent: Instance, from: Vector3, to: Vector3, width: number)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = from:Lerp(to, 0.5)
	local path = part({
		Name = "CampusPath",
		Size = Vector3.new(width, 0.4, length),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.05, 0), mid + delta.Unit + Vector3.new(0, 0.05, 0)),
		Color = Color3.fromRGB(196, 190, 176),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	tag(path, "TexPlaza")
end

local function buildLibrary(parent: Instance, center: Vector3)
	local W, D, H = 92, 68, 26
	local halfW, halfD = W / 2, D / 2
	tag(part({
		Name = "LibraryFloor",
		Size = Vector3.new(W, 1, D),
		CFrame = CFrame.new(center) * CFrame.new(0, -0.4, 0),
		Color = Color3.fromRGB(150, 118, 88),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	}), "TexWood")

	-- stone shell, open in the middle of the south face for the doors
	local walls = {
		{ size = Vector3.new(W, H, 2), offset = Vector3.new(0, H / 2, -halfD) },
		{ size = Vector3.new(2, H, D), offset = Vector3.new(-halfW, H / 2, 0) },
		{ size = Vector3.new(2, H, D), offset = Vector3.new(halfW, H / 2, 0) },
		{ size = Vector3.new(halfW - 8, H, 2), offset = Vector3.new(-(halfW / 2 + 4), H / 2, halfD) },
		{ size = Vector3.new(halfW - 8, H, 2), offset = Vector3.new(halfW / 2 + 4, H / 2, halfD) },
		{ size = Vector3.new(16, 8, 2), offset = Vector3.new(0, H - 4, halfD) }, -- over the doors
	}
	for i, wall in walls do
		tag(part({
			Name = "LibraryWall" .. i,
			Size = wall.size,
			CFrame = CFrame.new(center) * CFrame.new(wall.offset),
			Color = Color3.fromRGB(206, 198, 182),
			Material = Enum.Material.Sandstone,
			Parent = parent,
		}), "TexBrick")
	end

	-- portico: six columns and a pediment over the entrance
	-- Slimmer and further apart than they were: at 4 studs across on a 13 stud
	-- pitch the colonnade read as a fence and hid the building behind it. Each
	-- column now gets a base and a capital, without which a cylinder is a pipe.
	for i = -2, 2 do
		local cx = i * 18
		part({
			Name = "LibraryColumn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(H - 3, 3.2, 3.2),
			CFrame = CFrame.new(center) * CFrame.new(cx, (H - 3) / 2 + 1.6, halfD + 9) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(232, 226, 212),
			Material = Enum.Material.Marble,
			Parent = parent,
		})
		part({ Name = "LibraryColumnBase", Size = Vector3.new(4.6, 1.6, 4.6), CFrame = CFrame.new(center) * CFrame.new(cx, 0.8, halfD + 9), Color = Color3.fromRGB(226, 220, 206), Material = Enum.Material.Marble, Parent = parent })
		part({ Name = "LibraryColumnCap", Size = Vector3.new(4.8, 1.4, 4.8), CFrame = CFrame.new(center) * CFrame.new(cx, H - 0.7, halfD + 9), Color = Color3.fromRGB(236, 231, 218), Material = Enum.Material.Marble, Parent = parent })
	end
	-- entablature the columns actually carry
	part({ Name = "LibraryArchitrave", Size = Vector3.new(W - 4, 2.6, 7), CFrame = CFrame.new(center) * CFrame.new(0, H + 1.3, halfD + 9), Color = Color3.fromRGB(236, 231, 218), Material = Enum.Material.Marble, Parent = parent })
	part({
		Name = "LibraryPediment",
		Size = Vector3.new(W - 6, 5, 18),
		CFrame = CFrame.new(center) * CFrame.new(0, H + 2, halfD + 5),
		Color = Color3.fromRGB(232, 226, 212),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local plaque = part({
		Name = "LibrarySign",
		Size = Vector3.new(40, 4, 0.6),
		CFrame = CFrame.new(center) * CFrame.new(0, H + 2, halfD + 14),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(plaque, "CRUMBWORTH LIBRARY", Palette.BusYellow, Enum.NormalId.Front)
	signText(plaque, "SILENCE, PLEASE", Palette.BusYellow, Enum.NormalId.Back)

	local roof = part({
		Name = "LibraryRoof",
		Size = Vector3.new(W + 4, 1.5, D + 4),
		CFrame = CFrame.new(center) * CFrame.new(0, H + 0.5, 0),
		Color = Color3.fromRGB(96, 90, 84),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local _ = roof

	-- stacks: rows of shelves down both halves, with an aisle between
	for row = -1, 1 do
		for side = 0, 1 do
			local x = row * 26 + (side == 0 and -7 or 7)
			part({
				Name = "LibraryShelf",
				Size = Vector3.new(5, 12, 40),
				CFrame = CFrame.new(center) * CFrame.new(x, 6, -8),
				Color = Color3.fromRGB(146, 106, 72),
				Material = Enum.Material.WoodPlanks,
				Parent = parent,
			})
			-- a band of spines so the shelves are not brown slabs
			for shelfLevel = 1, 4 do
				part({
					Name = "LibraryBooks",
					Size = Vector3.new(5.4, 1.8, 38),
					CFrame = CFrame.new(center) * CFrame.new(x, shelfLevel * 2.7, -8),
					-- spines, not mud: a wider spread so a wall of books reads
					-- as many books rather than one brown mass
					Color = Color3.fromRGB(
						math.clamp(150 + (row + 1) * 34 + side * 26, 60, 250),
						math.clamp(96 + shelfLevel * 30 - side * 18, 50, 245),
						math.clamp(104 + side * 52 - shelfLevel * 12, 50, 240)
					),
					Material = Enum.Material.Fabric,
					Parent = parent,
				})
			end
		end
	end

	-- reading floor at the front: this is where the study desks land
	tag(part({
		Name = "LibraryReadingFloor",
		Size = Vector3.new(W - 8, 0.3, 22),
		CFrame = CFrame.new(center) * CFrame.new(0, 0.2, halfD - 13),
		Color = Color3.fromRGB(126, 60, 52),
		Material = Enum.Material.Carpet,
		Parent = parent,
	}), "TexCarpet")

	for _, lampX in { -30, 0, 30 } do
		part({
			Name = "LibraryChandelier",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5, 5, 5),
			CFrame = CFrame.new(center) * CFrame.new(lampX, H - 6, 0),
			Color = Color3.fromRGB(255, 236, 190),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 1.6
		light.Range = 44
		light.Color = Color3.fromRGB(255, 236, 196)
		light.Parent = parent:FindFirstChild("LibraryChandelier") :: Instance
	end
end

local function buildTennisStadium(parent: Instance, center: Vector3)
	-- two courts side by side, fenced, with stands down both long sides
	for _, courtX in { -24, 24 } do
		local surface = part({
			Name = "TennisCourt",
			Size = Vector3.new(38, 0.3, 78),
			CFrame = CFrame.new(center) * CFrame.new(courtX, 0.15, 0),
			Color = Color3.fromRGB(58, 110, 92),
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
		local _ = surface
		-- lines
		for _, line in {
			{ size = Vector3.new(27, 0.34, 0.5), offset = Vector3.new(0, 0.17, 0) },
			{ size = Vector3.new(27, 0.34, 0.5), offset = Vector3.new(0, 0.17, 21) },
			{ size = Vector3.new(27, 0.34, 0.5), offset = Vector3.new(0, 0.17, -21) },
			{ size = Vector3.new(0.5, 0.34, 78), offset = Vector3.new(-13.5, 0.17, 0) },
			{ size = Vector3.new(0.5, 0.34, 78), offset = Vector3.new(13.5, 0.17, 0) },
			{ size = Vector3.new(0.5, 0.34, 42), offset = Vector3.new(0, 0.17, 0) },
		} do
			part({
				Name = "CourtLine",
				Size = line.size,
				CFrame = CFrame.new(center) * CFrame.new(Vector3.new(courtX, 0, 0) + line.offset),
				Color = Color3.fromRGB(240, 240, 236),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			})
		end
		part({
			Name = "TennisNet",
			Size = Vector3.new(30, 3.6, 0.3),
			CFrame = CFrame.new(center) * CFrame.new(courtX, 1.8, 0),
			Color = Color3.fromRGB(40, 44, 48),
			Material = Enum.Material.Fabric,
			Transparency = 0.25,
			Parent = parent,
		})
		for _, postZ in { -15.5, 15.5 } do
			part({
				Name = "NetPost",
				Size = Vector3.new(0.8, 4.4, 0.8),
				CFrame = CFrame.new(center) * CFrame.new(courtX + (postZ > 0 and 15 or -15), 2.2, 0),
				Color = Color3.fromRGB(120, 124, 130),
				Material = Enum.Material.Metal,
				Parent = parent,
			})
		end
	end

	-- bleachers: stepped rows on both flanks
	for _, side in { -1, 1 } do
		for tier = 1, 6 do
			part({
				Name = "TennisStand",
				Size = Vector3.new(7, 2.4, 92),
				CFrame = CFrame.new(center) * CFrame.new(side * (56 + tier * 6), tier * 2.4 - 1.2, 0),
				Color = tier % 2 == 0 and Color3.fromRGB(196, 92, 76) or Color3.fromRGB(214, 206, 190),
				Material = Enum.Material.Concrete,
				Parent = parent,
			})
		end
	end

	-- floodlights at the four corners
	for _, cx in { -80, 80 } do
		for _, cz in { -52, 52 } do
			part({
				Name = "FloodPole",
				Size = Vector3.new(2, 46, 2),
				CFrame = CFrame.new(center) * CFrame.new(cx, 23, cz),
				Color = Color3.fromRGB(108, 112, 118),
				Material = Enum.Material.Metal,
				Parent = parent,
			})
			local head = part({
				Name = "FloodLamp",
				Size = Vector3.new(9, 4, 2.5),
				CFrame = CFrame.new(center) * CFrame.new(cx, 45, cz),
				Color = Color3.fromRGB(255, 246, 214),
				Material = Enum.Material.Neon,
				Parent = parent,
			})
			local light = Instance.new("SpotLight")
			light.Angle = 100
			light.Brightness = 2.4
			light.Range = 90
			light.Face = Enum.NormalId.Bottom
			light.Color = Color3.fromRGB(255, 248, 226)
			light.Parent = head
		end
	end

	local board = part({
		Name = "TennisScoreboard",
		Size = Vector3.new(30, 12, 1.4),
		CFrame = CFrame.new(center) * CFrame.new(0, 20, -56),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(board, "CRUMBWORTH TENNIS\nHOME 6   AWAY 4", Palette.BusYellow, Enum.NormalId.Front)
end

local function buildPool(parent: Instance, center: Vector3)
	local W, D, DEPTH = 76, 44, 13
	local halfW, halfD = W / 2, D / 2

	-- deck: four slabs around the basin, so the hole is a real hole
	local deck = 22
	for _, slab in {
		{ size = Vector3.new(W + deck * 2, 1, deck), offset = Vector3.new(0, -0.4, halfD + deck / 2) },
		{ size = Vector3.new(W + deck * 2, 1, deck), offset = Vector3.new(0, -0.4, -halfD - deck / 2) },
		{ size = Vector3.new(deck, 1, D), offset = Vector3.new(halfW + deck / 2, -0.4, 0) },
		{ size = Vector3.new(deck, 1, D), offset = Vector3.new(-halfW - deck / 2, -0.4, 0) },
	} do
		tag(part({
			Name = "PoolDeck",
			Size = slab.size,
			CFrame = CFrame.new(center) * CFrame.new(slab.offset),
			Color = Color3.fromRGB(226, 222, 212),
			Material = Enum.Material.CeramicTiles,
			Parent = parent,
		}), "TexPlaza")
	end

	-- basin
	part({
		Name = "PoolBottom",
		Size = Vector3.new(W, 1, D),
		CFrame = CFrame.new(center) * CFrame.new(0, -DEPTH - 0.5, 0),
		Color = Color3.fromRGB(126, 196, 224),
		Material = Enum.Material.CeramicTiles,
		Parent = parent,
	})
	for _, wall in {
		{ size = Vector3.new(W + 2, DEPTH, 1), offset = Vector3.new(0, -DEPTH / 2, halfD) },
		{ size = Vector3.new(W + 2, DEPTH, 1), offset = Vector3.new(0, -DEPTH / 2, -halfD) },
		{ size = Vector3.new(1, DEPTH, D), offset = Vector3.new(halfW, -DEPTH / 2, 0) },
		{ size = Vector3.new(1, DEPTH, D), offset = Vector3.new(-halfW, -DEPTH / 2, 0) },
	} do
		part({
			Name = "PoolWall",
			Size = wall.size,
			CFrame = CFrame.new(center) * CFrame.new(wall.offset),
			Color = Color3.fromRGB(206, 226, 236),
			Material = Enum.Material.CeramicTiles,
			Parent = parent,
		})
	end

	-- lane ropes
	for lane = -2, 2 do
		part({
			Name = "PoolLane",
			Size = Vector3.new(0.5, 0.4, D - 2),
			CFrame = CFrame.new(center) * CFrame.new(lane * 12, -1, 0),
			Color = lane % 2 == 0 and Color3.fromRGB(232, 96, 84) or Color3.fromRGB(240, 240, 240),
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
	end

	-- real terrain water, so this is a pool you swim in and not a blue floor
	local waterCenter = center + Vector3.new(0, -DEPTH / 2 - 0.5, 0)
	pcall(function()
		workspace.Terrain:FillBlock(
			CFrame.new(waterCenter),
			Vector3.new(W - 1, DEPTH - 1, D - 1),
			Enum.Material.Water
		)
	end)

	-- diving board over the deep end
	part({
		Name = "DivePlatform",
		Size = Vector3.new(6, 8, 6),
		CFrame = CFrame.new(center) * CFrame.new(-halfW - 6, 4, 0),
		Color = Color3.fromRGB(214, 208, 196),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	part({
		Name = "DiveBoard",
		Size = Vector3.new(14, 0.6, 4),
		CFrame = CFrame.new(center) * CFrame.new(-halfW + 2, 8.3, 0),
		Color = Color3.fromRGB(240, 240, 236),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	-- loungers and parasols down the sunny side
	for i = -2, 2 do
		part({
			Name = "PoolLounger",
			Size = Vector3.new(4, 1.4, 9),
			CFrame = CFrame.new(center) * CFrame.new(i * 16, 0.7, halfD + 10) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = Color3.fromRGB(244, 232, 210),
			Material = Enum.Material.Fabric,
			Parent = parent,
		})
		part({
			Name = "PoolParasolPole",
			Size = Vector3.new(0.5, 10, 0.5),
			CFrame = CFrame.new(center) * CFrame.new(i * 16 + 4, 5, halfD + 16),
			Color = Color3.fromRGB(180, 176, 168),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		part({
			Name = "PoolParasol",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 13, 13),
			CFrame = CFrame.new(center) * CFrame.new(i * 16 + 4, 10, halfD + 16) * CFrame.Angles(0, 0, math.rad(90)),
			Color = i % 2 == 0 and Color3.fromRGB(232, 108, 96) or Color3.fromRGB(246, 206, 96),
			Material = Enum.Material.Fabric,
			Parent = parent,
		})
	end

	local sign = part({
		Name = "PoolSign",
		Size = Vector3.new(26, 5, 1),
		CFrame = CFrame.new(center) * CFrame.new(0, 8, -halfD - 20),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	signText(sign, "CRUMBWORTH POOL\nNO RUNNING", Color3.fromRGB(140, 216, 240), Enum.NormalId.Front)
	signText(sign, "NO RUNNING", Color3.fromRGB(140, 216, 240), Enum.NormalId.Back)
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
	-- A plaque high on the wall, not a billboard on a post. The post used to be
	-- a solid 9-stud pillar standing at floor level in the middle of the room's
	-- edge, which is what was blocking doorways all over the school.
	local sign = part({
		Name = name .. "Sign",
		Size = Vector3.new(math.min(size.X - 6, 26), 3.4, 0.5),
		CFrame = CFrame.new(center) * CFrame.new(0, 12.4, -size.Y / 2 + 0.9),
		Color = Palette.Blackboard,
		Parent = parent,
	})
	sign.CanCollide = false
	signText(sign, label, Palette.Chalk, Enum.NormalId.Front)
	signText(sign, label, Palette.Chalk, Enum.NormalId.Back)
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
			CFrame = CFrame.new(-90 + (i - 1) * 60, 11.6, 0) ,
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
		{ dir = Vector3.new(-1, 0, 0), cf = CFrame.new(center + Vector3.new(-size.X / 2, 0, 0)) , len = size.Y },
		{ dir = Vector3.new(1, 0, 0), cf = CFrame.new(center + Vector3.new(size.X / 2, 0, 0)) , len = size.Y },
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

-- On the lawn beside the walk, not on the axis. A 26 stud pole dead centre in
-- front of the doors is the first thing a player sees and it stood between
-- them and the entrance.
local function buildFlagpole(parent: Instance)
	local FX = -38
	part({
		Name = "FlagpoleBase",
		Size = Vector3.new(5, 1.2, 5),
		CFrame = CFrame.new(FX, 0.6, 150),
		Color = Color3.fromRGB(206, 202, 192),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	part({
		Name = "Flagpole",
		Size = Vector3.new(0.8, 26, 0.8),
		CFrame = CFrame.new(FX, 13, 150),
		Color = Color3.fromRGB(190, 190, 195),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local flag = part({
		Name = "Flag",
		Size = Vector3.new(9, 5, 0.3),
		CFrame = CFrame.new(FX + 5.3, 22.5, 150),
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
					-- a warm stone against the pale floor: the old pillarbox red
					-- read as a diner, not a school atrium
					Color = Color3.fromRGB(176, 142, 120),
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
	for i = 1, 190 do
		local angle = (i / 190) * math.pi * 2 + rng:NextNumber(-0.02, 0.02)
		local dist = rng:NextNumber(292, 372)
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
	-- painterly terrain palette: warm grass, pale stone, so the horizon reads
	-- as painted hills instead of default grey rock
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 158, 70))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 152, 148))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(140, 108, 72))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(88, 146, 62))
	end)
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

	-- no terrain under any interior floor (air-carved, so no grass blades either)
	for _, region in {
		{ cf = CFrame.new(0, -2.3, 0), size = Vector3.new(452, 5, 252) }, -- main building (plan footprint)
		{ cf = CFrame.new(0, -2.3, -135), size = Vector3.new(104, 5, 26) }, -- gym protrusion
		{ cf = CFrame.new(-176, -2.3, -212), size = Vector3.new(64, 5, 54) }, -- boys dorm
		{ cf = CFrame.new(176, -2.3, -212), size = Vector3.new(64, 5, 54) }, -- girls dorm
		{ cf = CFrame.new(0, -2.3, -232), size = Vector3.new(96, 5, 72) }, -- library
	} do
		terrain:FillBlock(region.cf, region.size, Enum.Material.Air)
	end

	-- a few distant rocky peaks for the horizon
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + 0.3
		local dist = rng:NextNumber(430, 520)
		local pos = Vector3.new(math.cos(angle) * dist, rng:NextNumber(10, 30), math.sin(angle) * dist)
		terrain:FillBall(pos, rng:NextNumber(40, 80), Enum.Material.Grass)
		terrain:FillBall(pos + Vector3.new(0, 26, 0), rng:NextNumber(16, 30), Enum.Material.Rock)
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
		tag(part({ Name = "ShellBrickLow", Size = Vector3.new(segLen, 6, 2), CFrame = cf * CFrame.new(0, 3, 0) , Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
		tag(part({ Name = "ShellWindow", Size = Vector3.new(segLen, 4, 1.2), CFrame = cf * CFrame.new(0, 8, 0) , Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }), "TexWindow")
		local mullions = math.floor(segLen / 9)
		for m2 = 1, mullions - 1 do
			part({ Name = "ShellMullion", Size = Vector3.new(0.5, 4, 1.4), CFrame = cf * CFrame.new(-segLen / 2 + m2 * 9, 8, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
		tag(part({ Name = "ShellBrickHigh", Size = Vector3.new(segLen, 6, 2), CFrame = cf * CFrame.new(0, 13, 0) , Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
		-- white frames around the first-story windows (reference-art trim)
		part({ Name = "ShellSill", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 5.8, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "ShellLintel", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 10.2, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		if tall then
			-- second story: floor band, framed window band, brick, high parapet
			part({ Name = "ShellFloorBand", Size = Vector3.new(segLen, 1.4, 2.6), CFrame = cf * CFrame.new(0, 16.6, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			tag(part({ Name = "ShellWindow2", Size = Vector3.new(segLen, 4, 1.2), CFrame = cf * CFrame.new(0, 19.5, 0) , Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }), "TexWindow")
			local mullions2 = math.floor(segLen / 9)
			for m3 = 1, mullions2 - 1 do
				part({ Name = "ShellMullion2", Size = Vector3.new(0.5, 4, 1.4), CFrame = cf * CFrame.new(-segLen / 2 + m3 * 9, 19.5, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			end
			part({ Name = "ShellLintel2", Size = Vector3.new(segLen, 0.7, 2.3), CFrame = cf * CFrame.new(0, 21.8, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
			tag(part({ Name = "ShellBrickTop", Size = Vector3.new(segLen, 3.6, 2), CFrame = cf * CFrame.new(0, 24, 0) , Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
			part({ Name = "ShellParapet", Size = Vector3.new(segLen + 0.6, 1.2, 2.8), CFrame = cf * CFrame.new(0, 26.4, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		else
			part({ Name = "ShellParapet", Size = Vector3.new(segLen + 0.6, 1.2, 2.8), CFrame = cf * CFrame.new(0, 16.6, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	-- door frames at each gap
	for _, gap in gaps do
		local mid = from + unit * gap.at
		local cf = CFrame.lookAt(mid, mid + perp)
		for _, side in { -1, 1 } do
			part({ Name = "DoorPost", Size = Vector3.new(1.6, 12, 2.6), CFrame = cf * CFrame.new(side * (gap.width / 2 + 0.8), 6, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		end
		part({ Name = "DoorLintel", Size = Vector3.new(gap.width + 4, 2, 2.8), CFrame = cf * CFrame.new(0, 13, 0) , Color = Color3.fromRGB(226, 218, 196), Material = Enum.Material.Concrete, Parent = parent })
		if tall then
			-- fill the second story above the doorway so the wall reads solid
			tag(part({ Name = "GapUpperBrick", Size = Vector3.new(gap.width + 4, 12.4, 2), CFrame = cf * CFrame.new(0, 20.2, 0) , Color = Color3.fromRGB(168, 112, 82), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
			part({ Name = "GapParapet", Size = Vector3.new(gap.width + 4, 1.2, 2.8), CFrame = cf * CFrame.new(0, 26.4, 0) , Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
		end
	end
end

-- Clean interior partitions: navy wainscot + warm white upper, solid, with
-- framed door gaps. (The window-band builder is for exterior facades only.)
-- ===== mouldings =====
--
-- Every junction in the school used to be a raw 90 degree corner between two
-- prisms. Nothing in the painterly references has one: real architecture runs
-- a profile along every wall/floor, wall/ceiling and opening edge, and the
-- highlight that profile catches is what makes a surface read as built rather
-- than extruded.
--
-- The profiles are one-stud extrusions (see tools/make_trim.py), so they are
-- only ever scaled along their run and the cross-section stays exactly as
-- drawn at any length. A bevel baked into a cube would stretch into a wedge
-- the moment the wall was forty studs long.
-- MeshPart.MeshId cannot be assigned by a script, so the mouldings are not
-- built here. MapService records where each run goes and TrimService places
-- them afterwards from templates it loads through InsertService — the same
-- route MeshService already uses for the flora.
export type TrimRun = { kind: string, cframe: CFrame, length: number }

local trimRuns: { TrimRun } = {}

-- One run of moulding. `cf` puts the profile's origin corner where the wall
-- face meets the surface, +X along the run and -Z into the room.
local function moulding(cf: CFrame, kind: string, length: number)
	if length < 0.6 then
		return
	end
	table.insert(trimRuns, { kind = kind, cframe = cf, length = length })
end

-- Props are real furniture: CC0 models from Poly Haven, repacked as .glb and
-- uploaded to this account (tools/polyhaven.py). Same constraint as the
-- mouldings — MeshPart.MeshId is not assignable from a script — so MapService
-- only records where each one goes and PropService places it from a template.
--
-- `cframe` positions the prop's BASE CENTRE, because a desk is placed by where
-- its feet land, not by where the middle of its bounding box floats. `fallback`
-- is the block-built furniture standing in for it; PropService deletes that
-- once the real model has loaded, so a failed asset leaves a furnished room
-- rather than an empty one.
-- `hang` flips that: a pendant lamp is placed by the point it hangs from.
export type PropRequest = { kind: string, cframe: CFrame, scale: number?, hang: boolean?, fallback: Instance? }

local propRequests: { PropRequest } = {}

local function prop(kind: string, cf: CFrame, options: { scale: number?, hang: boolean?, fallback: Instance? }?)
	table.insert(propRequests, {
		kind = kind,
		cframe = cf,
		scale = options and options.scale,
		hang = options and options.hang,
		fallback = options and options.fallback,
	})
end

-- Naming a coordinate for every prop stops scaling somewhere around fifty of
-- them, and a room dressed by hand at that size reads as a showroom anyway:
-- everything squared up, evenly spaced, nothing where a person would have left
-- it. Clutter is scattered instead -- a rectangle of clear floor, a pool of
-- things that plausibly live there, and a seeded RNG so the same school comes
-- out of every server.
--
-- Sizes come from PropSizes, which is measured off the uploaded meshes
-- (tools/prop_registry.py). That is also what keeps the pools honest: a kind
-- whose model has not uploaded is simply absent from the table, so it drops
-- out of the pool instead of leaving a hole in the room.
type Zone = {
	min: Vector2,
	max: Vector2,
	y: number,
	pool: { string },
	count: number,
	seed: number,
	margin: number?,
}

local function scatter(zone: Zone)
	local available = {}
	for _, kind in zone.pool do
		if PropSizes[kind] then
			table.insert(available, kind)
		end
	end
	if #available == 0 then
		return
	end

	local rng = Random.new(zone.seed)
	local margin = zone.margin or 1
	local placed: { { at: Vector2, radius: number } } = {}

	-- Seed the occupancy with anything already placed by hand inside this
	-- rectangle. Without this the scatter cheerfully drops a planter through
	-- the dorm chest of drawers, because it only knows about its own picks.
	for _, existing in propRequests do
		local size = PropSizes[existing.kind]
		if not size then
			continue
		end
		local at = Vector2.new(existing.cframe.Position.X, existing.cframe.Position.Z)
		local radius = math.sqrt(size.X * size.X + size.Z * size.Z) * 0.5 + 0.5
		if at.X > zone.min.X - radius and at.X < zone.max.X + radius
			and at.Y > zone.min.Y - radius and at.Y < zone.max.Y + radius then
			table.insert(placed, { at = at, radius = radius })
		end
	end
	local prior = #placed

	local attempts = 0
	while #placed - prior < zone.count and attempts < zone.count * 40 do
		attempts += 1
		local kind = available[rng:NextInteger(1, #available)]
		local size = PropSizes[kind]
		-- circumradius: props are dropped at a random yaw, and half the longest
		-- side is not far enough for a box turned forty-five degrees
		local radius = math.sqrt(size.X * size.X + size.Z * size.Z) * 0.5 + 0.5
		local inset = margin + radius
		if zone.max.X - zone.min.X < inset * 2 or zone.max.Y - zone.min.Y < inset * 2 then
			continue
		end
		local at = Vector2.new(
			rng:NextNumber(zone.min.X + inset, zone.max.X - inset),
			rng:NextNumber(zone.min.Y + inset, zone.max.Y - inset)
		)
		local clear = true
		for _, other in placed do
			if (at - other.at).Magnitude < radius + other.radius then
				clear = false
				break
			end
		end
		if clear then
			table.insert(placed, { at = at, radius = radius })
			prop(kind, CFrame.new(at.X, zone.y, at.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
	end
end

local function buildInteriorWall(parent: Instance, from: Vector3, to: Vector3, gaps: { { at: number, width: number } })
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
		if isGap or segLen < 0.8 then
			continue
		end
		local mid = from + unit * ((a + b) / 2)
		local cf = CFrame.lookAt(mid, mid + perp)
		tag(part({ Name = "InnerWainscot", Size = Vector3.new(segLen, 4.6, 1.6), CFrame = cf * CFrame.new(0, 2.3, 0) , Color = Color3.fromRGB(94, 118, 158), Material = Enum.Material.SmoothPlastic, Parent = parent }), "TexWood")
		part({ Name = "InnerWainscotCap", Size = Vector3.new(segLen, 0.5, 1.8), CFrame = cf * CFrame.new(0, 4.75, 0) , Color = Color3.fromRGB(226, 222, 210), Material = Enum.Material.SmoothPlastic, Parent = parent })
		tag(part({ Name = "InnerWallUpper", Size = Vector3.new(segLen, 10.6, 1.4), CFrame = cf * CFrame.new(0, 10.3, 0) , Color = Color3.fromRGB(238, 234, 224), Material = Enum.Material.SmoothPlastic, Parent = parent }), "TexPlaster")

		-- skirting, chair rail and cornice down both faces of the run
		for _, face in { 1, -1 } do
			local run = cf * CFrame.Angles(0, face > 0 and 0 or math.pi, 0)
			local wallFace = run * CFrame.new(-segLen / 2, 0, -0.82)
			moulding(wallFace * CFrame.new(0, 0.05, 0), "skirting", segLen)
			moulding(wallFace * CFrame.new(0, 4.5, 0), "chairrail", segLen)
			moulding(wallFace * CFrame.new(0, 14.0, 0), "cornice", segLen)
		end
	end
	for _, gap in gaps do
		local mid = from + unit * gap.at
		local cf = CFrame.lookAt(mid, mid + perp)
		for _, side in { -1, 1 } do
			part({ Name = "InnerDoorPost", Size = Vector3.new(1.2, 11, 1.9), CFrame = cf * CFrame.new(side * (gap.width / 2 + 0.6), 5.5, 0) , Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
		end
		part({ Name = "InnerDoorLintel", Size = Vector3.new(gap.width + 2.6, 1.6, 1.9), CFrame = cf * CFrame.new(0, 11.8, 0) , Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "InnerDoorHeader", Size = Vector3.new(gap.width + 2.6, 3.9, 1.4), CFrame = cf * CFrame.new(0, 14.7, 0) , Color = Color3.fromRGB(238, 234, 224), Material = Enum.Material.SmoothPlastic, Parent = parent })

		-- architrave: two jambs and a head, framing the opening on both faces
		for _, face in { 1, -1 } do
			local run = cf * CFrame.Angles(0, face > 0 and 0 or math.pi, 0)
			local half = gap.width / 2 + 1.2
			for _, side in { -1, 1 } do
				moulding(run * CFrame.new(side * half, 0.1, -1.0) * CFrame.Angles(0, 0, math.rad(90)), "architrave", 12.4)
			end
			moulding(run * CFrame.new(-half, 12.5, -1.0), "architrave", half * 2)
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
-- An open swung door panel + frame at a doorway (doors, not floating gaps).
local function addOpenDoor(parent: Instance, hingeCf: CFrame, width: number, double: boolean?)
	local leaves = double and 2 or 1
	for i = 1, leaves do
		local side = i == 1 and -1 or 1
		local leafWidth = double and width / 2 - 0.3 or width - 0.6
		local panel = part({
			Name = "DoorPanel",
			Size = Vector3.new(leafWidth, 10.5, 0.35),
			CFrame = hingeCf
				* CFrame.new(side * (width / 2), 5.25, 0)
				* CFrame.Angles(0, math.rad(side * -105), 0)
				* CFrame.new(-side * leafWidth / 2, 0, 0),
			Color = Color3.fromRGB(96, 66, 44),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		part({
			Name = "DoorWindow",
			Size = Vector3.new(math.min(leafWidth * 0.4, 2), 2.4, 0.1),
			CFrame = panel.CFrame * CFrame.new(0, 2.2, -0.24),
			Color = Color3.fromRGB(180, 210, 230),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Parent = parent,
		})
	end
end

-- Interior floor plan: every homeroom becomes an enclosed room off the
-- hallway — front wall with a doorway, partitions between neighbors.
local function buildHomeroomWalls(parent: Instance)
	for _, zSign in { -1, 1 } do
		local z = zSign * 27
		-- hallway-facing wall with a doorway per homeroom
		buildWallRun(
			parent,
			Vector3.new(-156, 0, z),
			Vector3.new(156, 0, z),
			{ { at = 39, width = 16 }, { at = 117, width = 16 }, { at = 195, width = 16 }, { at = 273, width = 16 } }
		)
		-- doors standing open in each doorway
		for _, x in { -117, -39, 39, 117 } do
			local inward = Vector3.new(x, 0, zSign * 30)
			addOpenDoor(parent, CFrame.lookAt(Vector3.new(x, 0, z), inward), 16, true)
		end
		-- partitions between neighboring homerooms
		for _, x in { -78, 0, 78, -152, 152 } do
			part({
				Name = "HomeroomPartition",
				Size = Vector3.new(2, 13, 50),
				CFrame = CFrame.new(x, 6.5, zSign * 52),
				Color = Color3.fromRGB(214, 206, 186),
				Material = Enum.Material.Concrete,
				Parent = parent,
			})
		end
	end
end

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
				tag(part({ Name = "WingBackLow", Size = Vector3.new(segLen2, 10, 1.6), CFrame = segCf * CFrame.new(0, 5, -8) , Color = Color3.fromRGB(105, 118, 138), Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
			end
		end
		tag(part({ Name = "WingBackHigh", Size = Vector3.new(length, 9, 1.6), CFrame = cf * CFrame.new(0, 15, -8) , Color = Color3.fromRGB(105, 118, 138), Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
		-- second-floor balcony slab + railing
		part({ Name = "WingBalcony", Size = Vector3.new(length, 1, 9), CFrame = cf * CFrame.new(0, 10.2, -3.5) , Color = STONE, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "WingRailTop", Size = Vector3.new(length, 0.5, 0.5), CFrame = cf * CFrame.new(0, 13.4, 0.6) , Color = Color3.fromRGB(235, 235, 235), Parent = parent })
		part({ Name = "WingRailPanel", Size = Vector3.new(length, 2.2, 0.25), CFrame = cf * CFrame.new(0, 12.2, 0.6) , Color = Color3.fromRGB(210, 214, 220), Transparency = 0.25, Parent = parent })
		-- flat roof + parapet
		part({ Name = "WingTopRoof", Size = Vector3.new(length + 2, 1, 11), CFrame = cf * CFrame.new(0, 20.2, -3) , Color = Color3.fromRGB(154, 158, 164), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "WingTopParapet", Size = Vector3.new(length + 2, 1.6, 0.6), CFrame = cf * CFrame.new(0, 21.3, 2.2) , Color = STONE, Parent = parent })
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

-- Everything that is not architecture. A room reads as lived-in from the
-- clutter more than from the walls: a bin by the door, a plant in the corner,
-- a clock over the board. These are recorded, not built -- PropService places
-- them from Poly Haven templates once the models have loaded.
local function furnishProps()
	local function row(kind: string, y: number, yaw: number, points: { { number } })
		for _, pt in points do
			prop(kind, CFrame.new(pt[1], y, pt[2]) * CFrame.Angles(0, math.rad(yaw), 0))
		end
	end

	-- ---------------- lobby ----------------
	-- the clock tower comes down through the middle of the lobby, so the
	-- seating goes in the two side bays rather than across the doors
	-- the lobby stairs come down through x 41..51, so the seating stays inside
	-- them rather than under them
	prop("Sofa", CFrame.new(26, 0, 112) * CFrame.Angles(0, math.rad(90), 0))
	prop("Sofa2", CFrame.new(36, 0, 112) * CFrame.Angles(0, math.rad(-90), 0))
	prop("CoffeeTable", CFrame.new(31, 0, 112))
	prop("ArmChair", CFrame.new(31, 0, 106))
	prop("ArmChair", CFrame.new(31, 0, 118) * CFrame.Angles(0, math.pi, 0))
	prop("GrandfatherClock", CFrame.new(56, 0, 119) * CFrame.Angles(0, math.rad(-90), 0))
	prop("WhaleStatue", CFrame.new(-34, 0, 108), { scale = 2.0 })
	prop("RayStatue", CFrame.new(-56, 0, 112), { scale = 2.0 })
	prop("Vase1", CFrame.new(-38, 3.8, 92))
	prop("Vase2", CFrame.new(-22, 3.8, 92))
	row("PlanterPot", 0, 0, { { -56, 86 }, { 56, 86 }, { -56, 118 } })
	row("PottedPlant", 0, 0, { { -56, 100 }, { 56, 96 } })
	prop("Clock", CFrame.new(-40, 12, 102.8))

	-- ---------------- atrium ----------------
	row("PlanterBox", 0, 0, { { -28, -20 }, { 28, -20 }, { -28, 32 }, { 28, 32 } })
	row("PottedPlant", 0, 0, { { -34, 6 }, { 34, 6 } })
	row("Bin", 0, 0, { { -44, 30 }, { 44, 30 } })

	-- ---------------- corridors ----------------
	row("Bin", 0, 0, { { -56, 70 }, { 56, 70 }, { -56, -56 }, { 56, -56 } })
	row("Extinguisher", 0, 0, { { -57, 60 }, { 57, 60 }, { -57, -50 }, { 57, -50 } })
	row("WetFloorSign", 0, 25, { { -46, 46 }, { 40, -30 } })
	prop("Clock", CFrame.new(-58.4, 12, 20) * CFrame.Angles(0, math.rad(90), 0))
	prop("Clock", CFrame.new(58.4, 12, 20) * CFrame.Angles(0, math.rad(-90), 0))
	row("FireAlarm", 8, 90, { { -58.4, 40 } })
	row("FireAlarm", 8, -90, { { 58.4, 40 } })

	-- Room 101, the Music Room, the two science pavilions and the gym are
	-- dressed in furnishSubjectRooms, which knows what each room is for. What
	-- used to be here put a teacher's desk at x = -104, inside the homeroom
	-- next door, and a whole second classroom at z = -172 -- a field north of
	-- the gym.

	-- ---------------- library ----------------
	-- four study tables on the reading carpet, two chairs each
	for i, x in { -33, -11, 11, 33 } do
		prop("Table", CFrame.new(x, 0, -209))
		prop("Chair", CFrame.new(x, 0, -213) * CFrame.Angles(0, math.pi, 0))
		prop("Chair2", CFrame.new(x, 0, -205))
		if i % 2 == 1 then
			prop("Vase4", CFrame.new(x, 2.7, -209))
		end
	end
	prop("Sofa", CFrame.new(-38, 0, -217) * CFrame.Angles(0, math.rad(90), 0))
	prop("ArmChair", CFrame.new(38, 0, -217) * CFrame.Angles(0, math.rad(-90), 0))
	prop("SideTable", CFrame.new(-41, 0, -211) * CFrame.Angles(0, math.rad(90), 0))
	prop("LoungeChair", CFrame.new(41, 0, -211) * CFrame.Angles(0, math.rad(-90), 0))
	-- against the front wall either side of the doors, not down the aisles
	row("SteelShelves", 0, 180, { { -38, -202 }, { 38, -202 } })
	prop("Mirror", CFrame.new(0, 6, -264.4))
	prop("PictureFrame", CFrame.new(-24, 8, -264.4))
	prop("PictureFrame", CFrame.new(24, 8, -264.4))
	row("PlanterPot", 0, 0, { { -30, -201 }, { 30, -201 } })
	prop("Bin", CFrame.new(-38, 0, -204))

	-- ---------------- cafeteria ----------------
	-- The real cafeteria is the outer bay at x -224..-184, z -52..6. What used
	-- to be here laid four dining tables out at z 36..52, which is the middle
	-- of the principal's office.
	for _, cx in { -212, -198 } do
		for _, cz in { -40, -24 } do
			prop("DiningTable", CFrame.new(cx, 0, cz))
			prop("Bench", CFrame.new(cx, 0, cz - 4.4))
			prop("Bench", CFrame.new(cx, 0, cz + 4.4) * CFrame.Angles(0, math.pi, 0))
		end
	end
	prop("Stool", CFrame.new(-221, 0, -32))
	prop("Stool", CFrame.new(-189, 0, -32))
	prop("Bin", CFrame.new(-221, 0, -48))
	prop("Extinguisher", CFrame.new(-189, 0, -48))
	row("PottedPlant", 0, 0, { { -221, 1 }, { -189, 1 } })

	-- ---------------- the principal's office ----------------
	-- Everything here stays clear of x -222..-206, z 16..40: that is the
	-- sanctum shaft, and a filing cabinet standing in it would give the game
	-- away before the bookshelf did.
	prop("OfficeDesk", CFrame.new(-196, 0, 46) * CFrame.Angles(0, math.pi, 0))
	prop("Laptop", CFrame.new(-196, 2.9, 46))
	prop("Notepads", CFrame.new(-192, 2.9, 46))
	prop("ArmChair", CFrame.new(-196, 0, 52) * CFrame.Angles(0, math.pi, 0))
	prop("SchoolChair", CFrame.new(-200, 0, 40))
	prop("SchoolChair", CFrame.new(-192, 0, 40))
	prop("Cabinet", CFrame.new(-187, 0, 56) * CFrame.Angles(0, math.rad(-90), 0))
	prop("SteelShelves2", CFrame.new(-187, 0, 46) * CFrame.Angles(0, math.rad(-90), 0))
	prop("GrandfatherClock", CFrame.new(-187, 0, 12) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Sofa", CFrame.new(-214, 0, 10) * CFrame.Angles(0, math.rad(90), 0))
	prop("CoffeeTable", CFrame.new(-208, 0, 10))
	prop("PottedPlant", CFrame.new(-189, 0, 60))
	prop("Vase1", CFrame.new(-199, 2.9, 46))
	prop("Bin", CFrame.new(-203, 0, 60))
	prop("FramedPicture", CFrame.new(-204, 9, 63.2) * CFrame.Angles(0, math.pi, 0))

	-- ---------------- gym ----------------
	row("Football", 0, 0, { { -22, -98 }, { 18, -112 } })
	row("AmericanFootball", 0, 0, { { 8, -94 } })
	row("Baseball", 0, 0, { { -12, -118 } })
	prop("Dartboard", CFrame.new(-48.4, 8, -105) * CFrame.Angles(0, math.rad(90), 0))
	row("Bin", 0, 0, { { -46, -70 }, { 46, -70 } })

	-- ---------------- dorms ----------------
	for _, sx in { -1, 1 } do
		local cx = sx * 176
		prop("DayBed", CFrame.new(cx - sx * 16, 0, -226) * CFrame.Angles(0, math.rad(sx * 90), 0))
		prop("Nightstand", CFrame.new(cx - sx * 16, 0, -218) * CFrame.Angles(0, math.rad(sx * 90), 0))
		prop("Drawer", CFrame.new(cx + sx * 16, 0, -226) * CFrame.Angles(0, math.rad(-sx * 90), 0))
		prop("Cabinet", CFrame.new(cx + sx * 16, 0, -216) * CFrame.Angles(0, math.rad(-sx * 90), 0))
		prop("Pillows", CFrame.new(cx - sx * 16, 1.9, -226))
		prop("Television", CFrame.new(cx + sx * 16, 3.3, -226) * CFrame.Angles(0, math.rad(-sx * 90), 0))
		prop("Boombox", CFrame.new(cx + sx * 16, 3.3, -216) * CFrame.Angles(0, math.rad(-sx * 90), 0))
		prop("LoungeChair", CFrame.new(cx, 0, -204) * CFrame.Angles(0, math.pi, 0))
		prop("ModernCoffeeTable", CFrame.new(cx, 0, -198))
		prop("PottedPlant", CFrame.new(cx - sx * 22, 0, -200))
		prop("Bin", CFrame.new(cx + sx * 22, 0, -200))
	end

	-- ---------------- grounds ----------------
	row("PicnicTable", 0, 0, { { -86, 150 }, { 86, 150 }, { -86, 176 }, { 86, 176 } })
	row("PlanterBox", 0, 0, { { -44, 138 }, { 44, 138 }, { -70, 138 }, { 70, 138 } })
	row("Shrub", 0, 0, {
		{ -110, 130 }, { -100, 143 }, { 100, 143 }, { 110, 130 },
		{ -130, 96 }, { 130, 96 }, { -150, 40 }, { 150, 40 },
	})
	row("Flowers", 0, 0, {
		{ -52, 132 }, { -36, 132 }, { 36, 132 }, { 52, 132 },
		{ -120, 112 }, { 120, 112 },
	})
	row("SecurityLight", 9, 0, { { -62, 126.5 }, { 62, 126.5 } })
	row("IndustrialLamp", 9, 180, { { -30, 126.5 }, { 30, 126.5 } })
	prop("Bin", CFrame.new(-32, 0, 133))
	prop("Bin", CFrame.new(32, 0, 133))

	-- ---------------- second dressing pass ----------------
	-- the pieces that turn a furnished room into an inhabited one
	prop("Ottoman", CFrame.new(23, 0, 106))
	prop("GreenChair", CFrame.new(-56, 0, 96) * CFrame.Angles(0, math.rad(90), 0))
	prop("FramedPicture", CFrame.new(-44, 9, 102.8))
	prop("FramedPicture", CFrame.new(38, 9, 102.8))
	prop("Table2", CFrame.new(0, 0, -216))
	prop("Chair", CFrame.new(0, 0, -220) * CFrame.Angles(0, math.pi, 0))
	prop("Fern", CFrame.new(-35, 0, -209))
	prop("Fern", CFrame.new(35, 0, -209))
	for _, x in { -15, 15 } do
		prop("CeilingLamp", CFrame.new(x, 24.5, -232), { hang = true })
	end
	for _, z in { 36, 50 } do
		prop("HangingLamp", CFrame.new(-204, 13, z), { hang = true })
	end
	-- stacking chairs along the gym wall, left out after an assembly
	for i = 0, 3 do
		prop("MonoblocChair", CFrame.new(-44, 0, -76 + i * 9) * CFrame.Angles(0, math.rad(90 + i * 7), 0))
	end

	-- ---------------- scattered clutter ----------------
	local MAINTENANCE = {
		"WoodenCrate", "WoodenCrate2", "Barrel", "Barrel2", "Barrel3", "WineBarrel",
		"WoodenBucket", "WoodenBucket2", "PlasticCrate", "PlasticContainer",
		"IndustrialPasticContainer", "MetalToolbox", "MetalToolChest", "HandTruck",
		"WoodenLadder", "WoodenLadder2", "WornMetalRack", "UtilityBox", "UtilityBox2",
		"Trashbag", "OldTyre", "CompostBag", "WoodenBroom", "SteelFrameShelves",
	}
	local SPORTS = {
		"MetalStool", "MetalStool2", "MetalStool3", "FoldingWoodenStool", "WoodenStool",
		"MonoblocChair", "Bin", "Lifebuoy", "OldTyre", "WoodenCrate", "PlasticCrate",
	}
	local KITCHEN = {
		"BrassPot", "BrassPot2", "BrassPan", "PotEnamel", "MetalJug", "Jug",
		"VintageMicrowave", "VintageElectricKettle", "PlasticThermos", "WoodenBowl",
		"WoodenCuttingBoard", "LongLifeFood", "RussianFoodCans", "PlasticBottleGallon",
		"HamburgerBuns", "CarrotCake", "BrassGoblets",
	}
	local CLASSROOM_CLUTTER = {
		"WoodenCrate2", "PlasticCrate", "MetalStool", "FoldingWoodenStool", "Bin",
		"SteelShelves2", "WoodenDisplayShelves", "PottedPlant", "CeramicPot",
		"MedicalBox", "PlasticContainer", "SmallWoodenTable",
	}
	local GARDEN = {
		"PlanterBox", "PlanterBox2", "PlanterBox3", "PlanterPot", "CeramicPot",
		"Shrub", "Flowers", "SeedingTray", "WateringCanMetal", "GardenSprinkler",
		"GardenGloves", "CompostBag", "WoodenBucket", "Fern",
	}
	local TERRACE = {
		"PicnicTable", "OutdoorTableChairSet", "RoundWoodenTable", "RoundWoodenTable2",
		"MonoblocChair", "Bench", "Stool", "PlanterBox2", "Shrub", "Bin",
	}

	for _, zone in {
		-- the gym keeps its equipment down the flanks
		{ min = Vector2.new(-48, -118), max = Vector2.new(-42, -70), y = 0, pool = MAINTENANCE, count = 12, seed = 3101 },
		{ min = Vector2.new(42, -118), max = Vector2.new(48, -70), y = 0, pool = SPORTS, count = 10, seed = 3102 },
		-- the servery end of the cafeteria
		{ min = Vector2.new(-221, 49), max = Vector2.new(-208, 58), y = 0, pool = KITCHEN, count = 10, seed = 3103 },
		-- the back of the two homerooms flanking each wing corridor
		{ min = Vector2.new(-150, -120), max = Vector2.new(-140, -100), y = 0, pool = CLASSROOM_CLUTTER, count = 6, seed = 3104 },
		{ min = Vector2.new(140, -120), max = Vector2.new(150, -100), y = 0, pool = CLASSROOM_CLUTTER, count = 6, seed = 3105 },
		-- the courtyard edges, left and right of the way through
		{ min = Vector2.new(-40, 34), max = Vector2.new(-30, 66), y = 0, pool = GARDEN, count = 8, seed = 3106 },
		{ min = Vector2.new(30, 34), max = Vector2.new(40, 66), y = 0, pool = GARDEN, count = 8, seed = 3107 },
		-- the lawn either side of the front approach
		{ min = Vector2.new(-104, 166), max = Vector2.new(-70, 182), y = 0, pool = TERRACE, count = 7, seed = 3108 },
		{ min = Vector2.new(70, 166), max = Vector2.new(104, 182), y = 0, pool = TERRACE, count = 7, seed = 3109 },
		-- the dorm yards
		{ min = Vector2.new(-198, -234), max = Vector2.new(-180, -214), y = 0, pool = GARDEN, count = 6, seed = 3110 },
		{ min = Vector2.new(180, -234), max = Vector2.new(198, -214), y = 0, pool = GARDEN, count = 6, seed = 3111 },
	} do
		scatter(zone)
	end
end

-- furnishClassroom and furnishCafeteria used to live here. Neither was ever
-- called: one furnished a classroom at z = -150, which is a field north of the
-- gym, and the other a cafeteria that buildCafeteriaTables already builds. The
-- rooms that exist are furnished in furnishSubjectRooms.

local function detailGym(parent: Instance)
	local c = Vector3.new(215, 0, 60)
	-- red/white pennant stripe around the top of the walls
	for i = 0, 15 do
		part({ Name = "GymStripe", Size = Vector3.new(4.2, 2.2, 0.4), CFrame = CFrame.new(c.X - 32 + i * 4.3, 12.5, c.Z - 33.6), Color = i % 2 == 0 and Color3.fromRGB(196, 44, 44) or Color3.fromRGB(240, 240, 240), Parent = parent })
	end
	-- high window band
	part({ Name = "GymWindowBand", Size = Vector3.new(50, 3.2, 0.5), CFrame = CFrame.new(c.X, 10, c.Z + 33.6), Color = Color3.fromRGB(200, 224, 240), Material = Enum.Material.Glass, Transparency = 0.4, Parent = parent })
	-- cool-white sport lighting overhead
	for _, off in { -20, 0, 20 } do
		local strip = part({ Name = "GymLightStrip", Size = Vector3.new(40, 0.4, 1.2), CFrame = CFrame.new(c.X, 13.2, c.Z + off), Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Neon, Parent = parent })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(225, 240, 255)
		light.Brightness = 1.3
		light.Range = 34
		light.Parent = strip
	end

	-- basketball hoop on the gym wall
	part({ Name = "GymBoard", Size = Vector3.new(6, 4, 0.4), CFrame = CFrame.new(c.X, 9.6, c.Z - 32.8), Color = Color3.fromRGB(240, 240, 240), Parent = parent })
	part({ Name = "GymRim", Size = Vector3.new(1.6, 0.3, 1.6), CFrame = CFrame.new(c.X, 8.2, c.Z - 31.6), Color = Color3.fromRGB(226, 100, 60), Material = Enum.Material.Neon, Parent = parent })
end


-- Three-storey exterior facade: brick piers, tall framed windows per floor,
-- white trim banding between floors, dentil cornice at the top. This is what
-- makes the school read as a civic academy instead of a strip mall.
local FACADE_H = 38
local function buildFacadeWall(parent: Instance, from: Vector3, to: Vector3, gaps: { { at: number, width: number } })
	local BRICK = Color3.fromRGB(138, 78, 62)
	local TRIM = Color3.fromRGB(238, 236, 228)
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
		local function slab(name: string, w: number, h: number, d: number, y: number, color: Color3, mat: Enum.Material, texTag: string?)
			local p = part({ Name = name, Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, y, 0) , Color = color, Material = mat, Parent = parent })
			if texTag then
				tag(p, texTag)
			end
			return p
		end
		-- base course
		slab("FacadeBase", segLen, 3.2, 2.6, 1.6, Color3.fromRGB(198, 194, 184), Enum.Material.Concrete, "TexBlueStone")
		-- three storeys of solid brick with punched, white-framed windows
		for floor = 0, 2 do
			local y0 = 3.2 + floor * 11.6
			-- the wall itself is brick, full height of the storey
			slab("FacadeBrick", segLen, 11.6, 2.2, y0 + 5.8, BRICK, Enum.Material.Brick, "TexBrick")
			-- punched windows: one per bay, brick left between them
			local bays = math.max(1, math.round(segLen / 16))
			local pitch = segLen / bays
			local winW = math.min(7.5, pitch * 0.5)
			for m = 0, bays - 1 do
				local wx = -segLen / 2 + (m + 0.5) * pitch
				part({ Name = "FacadeWinFrame", Size = Vector3.new(winW + 2.0, 8.4, 2.6), CFrame = cf * CFrame.new(wx, y0 + 6.2, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
				local pane = part({ Name = "FacadeWindow", Size = Vector3.new(winW, 6.6, 2.9), CFrame = cf * CFrame.new(wx, y0 + 6.2, 0) , Color = Color3.fromRGB(96, 138, 170), Material = Enum.Material.SmoothPlastic, Reflectance = 0.3, Parent = parent })
				tag(pane, "TexWindow")
				-- muntin cross
				part({ Name = "Muntin", Size = Vector3.new(0.45, 6.6, 3.0), CFrame = cf * CFrame.new(wx, y0 + 6.2, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
				part({ Name = "Muntin", Size = Vector3.new(winW, 0.45, 3.0), CFrame = cf * CFrame.new(wx, y0 + 6.2, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
				-- sill under each window
				part({ Name = "FacadeSill", Size = Vector3.new(winW + 2.6, 0.6, 2.5), CFrame = cf * CFrame.new(wx, y0 + 1.7, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
				-- keystone above and shutters either side: relief, not flat color
				part({ Name = "Keystone", Size = Vector3.new(2.0, 2.2, 2.8), CFrame = cf * CFrame.new(wx, y0 + 10.6, 0), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
				for _, sh in { -1, 1 } do
					part({ Name = "Shutter", Size = Vector3.new(2.4, 7.0, 2.7), CFrame = cf * CFrame.new(wx + sh * (winW / 2 + 2.2), y0 + 6.2, 0), Color = Color3.fromRGB(46, 74, 60), Material = Enum.Material.WoodPlanks, Parent = parent })
				end
			end
			-- slim string course between storeys only
			if floor < 2 then
				slab("FacadeStringCourse", segLen + 0.4, 0.9, 2.5, y0 + 11.4, TRIM, Enum.Material.Concrete)
			end
		end
		-- cornice + dentils
		slab("FacadeCornice", segLen + 0.6, 1.8, 3.2, FACADE_H - 0.6, TRIM, Enum.Material.Concrete)
		local dentils = math.floor(segLen / 4)
		for dI = 0, dentils do
			part({ Name = "Dentil", Size = Vector3.new(1.6, 1.0, 2.9), CFrame = cf * CFrame.new(-segLen / 2 + dI * 4, FACADE_H - 2.2, 0) , Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	for _, gap in gaps do
		local mid = from + unit * gap.at
		local cf = CFrame.lookAt(mid, mid + perp)
		for _, side in { -1, 1 } do
			part({ Name = "FacadeDoorPost", Size = Vector3.new(2.4, 15, 3.0), CFrame = cf * CFrame.new(side * (gap.width / 2 + 1.2), 7.5, 0) , Color = Color3.fromRGB(238, 236, 228), Material = Enum.Material.Concrete, Parent = parent })
		end
		part({ Name = "FacadeDoorLintel", Size = Vector3.new(gap.width + 5, 2.4, 3.0), CFrame = cf * CFrame.new(0, 16.2, 0) , Color = Color3.fromRGB(238, 236, 228), Material = Enum.Material.Concrete, Parent = parent })
		tag(part({ Name = "FacadeGapBrick", Size = Vector3.new(gap.width + 5, 20, 2.2), CFrame = cf * CFrame.new(0, 27.4, 0) , Color = Color3.fromRGB(138, 78, 62), Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
	end
end

-- ============================ GRAND FACADE ============================
-- The reference is a civic brick academy: pitched slate roofs with dormers,
-- a central clock tower over a columned portico, corner towers with
-- crenellations, white trim banding every floor, and hedges hugging the base.
local function buildGrandFacade(parent: Instance)
	local BRICK = Color3.fromRGB(138, 78, 62)
	local TRIM = Color3.fromRGB(238, 236, 228)
	local SLATE = Color3.fromRGB(64, 74, 84)
	local Z = 124 -- south facade line

	local function trimBand(x: number, y: number, z: number, w: number, d: number, h: number?)
		part({ Name = "FacadeTrim", Size = Vector3.new(w, h or 1.4, d), CFrame = CFrame.new(x, y, z), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end

	-- ---- pitched roofs over the room rows (wedge pairs) ----
	local function pitchedRoof(cx: number, cz: number, w: number, d: number, h: number, baseY: number)
		for _, side in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "PitchRoof"
			wedge.Anchored = true
			wedge.Size = Vector3.new(w, h, d / 2)
			wedge.CFrame = CFrame.new(cx, baseY + h / 2, cz + side * d / 4)
				* CFrame.Angles(0, side > 0 and 0 or math.rad(180), 0)
			wedge.Color = SLATE
			wedge.Material = Enum.Material.Slate
			wedge.Parent = parent
			tag(wedge, "TexRoof")
		end
		-- eaves overhang + carved brackets underneath
		trimBand(cx, baseY - 0.3, cz + d / 2, w + 4, 2.4, 1.2)
		trimBand(cx, baseY - 0.3, cz - d / 2, w + 4, 2.4, 1.2)
		local brackets = math.floor(w / 14)
		for bI = 0, brackets do
			local bx = cx - w / 2 + bI * (w / math.max(brackets, 1))
			for _, bz in { cz + d / 2, cz - d / 2 } do
				part({ Name = "EaveBracket", Size = Vector3.new(1.4, 2.6, 3.2), CFrame = CFrame.new(bx, baseY - 2.0, bz), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
			end
		end
	end

	-- dormer windows punched into a pitched roof face
	local function dormers(cx: number, cz: number, w: number, count: number, baseY: number, face: number)
		for i = 1, count do
			local x = cx - w / 2 + (i - 0.5) * (w / count)
			local z = cz + face * 9
			part({ Name = "DormerBody", Size = Vector3.new(7, 7, 8), CFrame = CFrame.new(x, baseY + 3.4, z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent })
			local roof = Instance.new("WedgePart")
			roof.Name = "DormerRoof"
			roof.Anchored = true
			roof.Size = Vector3.new(8.4, 3.4, 4.6)
			roof.CFrame = CFrame.new(x, baseY + 8.6, z + face * 1.8) * CFrame.Angles(0, face > 0 and 0 or math.rad(180), 0)
			roof.Color = SLATE
			roof.Material = Enum.Material.Slate
			roof.Parent = parent
			local pane = part({ Name = "DormerWindow", Size = Vector3.new(4.4, 4.6, 0.5), CFrame = CFrame.new(x, baseY + 3.6, z + face * 4.1), Color = Color3.fromRGB(196, 224, 240), Material = Enum.Material.Glass, Transparency = 0.25, Parent = parent })
			tag(pane, "TexWindow")
			trimBand(x, baseY + 6.1, z + face * 4.2, 5.4, 0.7, 0.7)
			trimBand(x, baseY + 1.1, z + face * 4.2, 5.4, 0.7, 0.7)
		end
	end

	pitchedRoof(-142, 100, 164, 48, 14, 38.0)
	pitchedRoof(142, 100, 164, 48, 14, 38.0)
	dormers(-142, 100, 150, 5, 38.0, 1)
	dormers(142, 100, 150, 5, 38.0, 1)
	pitchedRoof(-142, -94, 164, 60, 15, 38.0)
	pitchedRoof(142, -94, 164, 60, 15, 38.0)
	pitchedRoof(-198, 0, 52, 128, 12, 38.0)
	pitchedRoof(198, 0, 52, 128, 12, 38.0)
	-- gym: taller, its own ridge
	pitchedRoof(0, -105, 104, 86, 18, 38.0)

	-- ---- central block: portico, clock tower, grand steps ----
	-- projecting entrance bay (the white stone block in the reference)
	-- the bay is a frame, not a plug: piers each side, header above, so the
	-- doors underneath actually open into the lobby
	for _, side in { -1, 1 } do
		part({ Name = "EntryBayPier", Size = Vector3.new(15, 46, 14), CFrame = CFrame.new(side * 20.5, 23, Z + 5), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "EntryBayHeader", Size = Vector3.new(56, 26, 14), CFrame = CFrame.new(0, 33, Z + 5), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- arched transom over the doors
	part({ Name = "EntryTransom", Size = Vector3.new(24, 4.6, 1.2), CFrame = CFrame.new(0, 17.4, Z - 1.6), Color = Color3.fromRGB(150, 196, 222), Material = Enum.Material.Glass, Transparency = 0.25, Parent = parent })
	part({ Name = "EntryTransomBar", Size = Vector3.new(0.5, 4.6, 1.5), CFrame = CFrame.new(0, 17.4, Z - 1.7), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- double doors, swung open
	for _, side in { -1, 1 } do
		part({
			Name = "MainDoor",
			Size = Vector3.new(11, 14, 0.9),
			CFrame = CFrame.new(side * 11.5, 7.6, Z - 2.2) * CFrame.Angles(0, side * math.rad(72), 0),
			Color = Color3.fromRGB(96, 60, 40),
			Material = Enum.Material.WoodPlanks,
			Parent = parent,
		})
		part({
			Name = "MainDoorGlass",
			Size = Vector3.new(6.4, 7, 1.1),
			CFrame = CFrame.new(side * 11.5, 10.2, Z - 2.2) * CFrame.Angles(0, side * math.rad(72), 0),
			Color = Color3.fromRGB(150, 196, 222),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Parent = parent,
		})
	end
	-- door surround
	for _, side in { -1, 1 } do
		part({ Name = "EntryJambStone", Size = Vector3.new(3, 16, 6), CFrame = CFrame.new(side * 13.5, 8, Z + 1), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	part({ Name = "EntryLintelStone", Size = Vector3.new(30, 2.4, 6), CFrame = CFrame.new(0, 16.8, Z + 1), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	-- Articulation on the bay face. It was a 56 x 46 slab of blank concrete,
	-- which is the first thing anyone sees when they arrive. Real civic
	-- frontages break that mass up: pilasters carry the eye up, string courses
	-- carry it across, and tall windows give the storey above the doors
	-- something to be.
	local bayFace = Z + 12.2
	-- outboard of the portico columns at +/-11, not on top of them
	for _, px in { -25, -38, 25, 38 } do
		part({ Name = "EntryPilaster", Size = Vector3.new(4.4, 40, 1.6), CFrame = CFrame.new(px, 21, bayFace), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		-- a capital block so the pilaster lands somewhere
		part({ Name = "EntryPilasterCap", Size = Vector3.new(5.6, 1.8, 2.2), CFrame = CFrame.new(px, 41.6, bayFace), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "EntryPilasterBase", Size = Vector3.new(5.6, 2.2, 2.2), CFrame = CFrame.new(px, 2.1, bayFace), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	-- Brick to the first string course, stone above. The bay was one uniform
	-- slab of trim concrete from the pavement to the pediment, which reads as
	-- a blank wall however much moulding is stuck to it. Civic buildings put a
	-- heavier material at the bottom and it is what gives the front a base.
	for _, side in { -1, 1 } do
		tag(part({ Name = "EntryBayBrick", Size = Vector3.new(15.4, 19, 1.4), CFrame = CFrame.new(side * 20.5, 9.5, bayFace - 0.1), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
	end
	part({ Name = "EntryBayPlinth", Size = Vector3.new(58, 2.4, 2.6), CFrame = CFrame.new(0, 1.2, bayFace - 0.2), Color = Color3.fromRGB(198, 194, 184), Material = Enum.Material.Concrete, Parent = parent })

	-- string courses at the floor lines
	for _, band in { { y = 19.6, h = 1.6 }, { y = 43.4, h = 2.0 } } do
		part({ Name = "EntryStringCourse", Size = Vector3.new(58, band.h, 2.4), CFrame = CFrame.new(0, band.y, bayFace - 0.2), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	-- three tall windows in the storey over the doors
	-- two windows flanking the name sign, which owns the centre of the bay
	for _, wx in { -17.5, 17.5 } do
		local pane = part({ Name = "EntryBayWindow", Size = Vector3.new(9, 17, 1), CFrame = CFrame.new(wx, 30.5, bayFace - 0.4), Color = Color3.fromRGB(150, 196, 222), Material = Enum.Material.Glass, Transparency = 0.2, Parent = parent })
		tag(pane, "TexWindow")
		part({ Name = "EntryWinSurround", Size = Vector3.new(11, 19, 1.4), CFrame = CFrame.new(wx, 30.5, bayFace - 0.9), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "EntryWinKeystone", Size = Vector3.new(2.2, 3, 2), CFrame = CFrame.new(wx, 40.6, bayFace + 0.1), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end
	-- cheek walls flanking the steps, so the approach is funnelled
	for _, side in { -1, 1 } do
		part({ Name = "EntryCheek", Size = Vector3.new(3, 5.5, 16), CFrame = CFrame.new(side * 21, 2.6, Z + 22), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "EntryCheekCap", Size = Vector3.new(4, 1, 17), CFrame = CFrame.new(side * 21, 5.7, Z + 22), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "EntryUrn", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 4.4, 4.4), CFrame = CFrame.new(side * 21, 8, Z + 14.5), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end

	trimBand(0, 46.4, Z + 5, 60, 16, 2.2)
	-- pediment over the bay
	local ped = Instance.new("WedgePart")
	ped.Name = "Pediment"
	ped.Anchored = true
	ped.Size = Vector3.new(56, 8, 7)
	ped.CFrame = CFrame.new(0, 51.6, Z + 8.5) * CFrame.Angles(0, 0, 0)
	ped.Color = TRIM
	ped.Material = Enum.Material.Concrete
	ped.Parent = parent
	local ped2 = Instance.new("WedgePart")
	ped2.Name = "Pediment"
	ped2.Anchored = true
	ped2.Size = Vector3.new(56, 8, 7)
	ped2.CFrame = CFrame.new(0, 51.6, Z + 1.5) * CFrame.Angles(0, math.rad(180), 0)
	ped2.Color = TRIM
	ped2.Material = Enum.Material.Concrete
	ped2.Parent = parent

	-- portico columns
	for i = -2, 2 do
		if i ~= 0 then
			part({ Name = "PorticoColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(34, 3.4, 3.4), CFrame = CFrame.new(i * 11, 17, Z + 13) * CFrame.Angles(0, 0, math.rad(90)), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
			part({ Name = "ColumnCap", Size = Vector3.new(4.6, 1.2, 4.6), CFrame = CFrame.new(i * 11, 34.3, Z + 13), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
			part({ Name = "ColumnBase", Size = Vector3.new(4.6, 1.2, 4.6), CFrame = CFrame.new(i * 11, 0.6, Z + 13), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		end
	end
	part({ Name = "PorticoRoof", Size = Vector3.new(78, 2.6, 18), CFrame = CFrame.new(0, 34.6, Z + 12), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })

	-- grand steps
	for i = 0, 4 do
		part({ Name = "GrandStep", Size = Vector3.new(46 - i * 2, 1, 12 - i * 1.6), CFrame = CFrame.new(0, 0.5 + i * 0.9, Z + 22 - i * 1.2), Color = Color3.fromRGB(206, 202, 192), Material = Enum.Material.Concrete, Parent = parent })
	end

	-- clock tower rising behind the portico
	local towerZ = Z - 6
	tag(part({ Name = "ClockTower", Size = Vector3.new(24, 54, 24), CFrame = CFrame.new(0, 44, towerZ), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
	trimBand(0, 71.6, towerZ, 26, 26, 2.0)
	part({ Name = "TowerClockBlock", Size = Vector3.new(25, 15, 25), CFrame = CFrame.new(0, 80, towerZ), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	trimBand(0, 88.2, towerZ, 27.5, 27.5, 2.0)
	tag(part({ Name = "TowerCap", Size = Vector3.new(21, 6, 21), CFrame = CFrame.new(0, 91.8, towerZ), Color = SLATE, Material = Enum.Material.Slate, Parent = parent }), "TexRoof")
	part({ Name = "TowerSpire", Size = Vector3.new(1.5, 11, 1.5), CFrame = CFrame.new(0, 100.2, towerZ), Color = Color3.fromRGB(255, 196, 60), Material = Enum.Material.Metal, Parent = parent })
	for _, spec in {
		{ z = towerZ + 12.6, n = Enum.NormalId.Front },
		{ z = towerZ - 12.6, n = Enum.NormalId.Back },
	} do
		local face = part({ Name = "ClockFace", Size = Vector3.new(11, 11, 0.5), CFrame = CFrame.new(0, 80, spec.z), Color = Color3.fromRGB(244, 240, 230), Material = Enum.Material.SmoothPlastic, Parent = parent })
		local dir = spec.n == Enum.NormalId.Front and 1 or -1
		part({ Name = "ClockRing", Size = Vector3.new(12.6, 12.6, 0.3), CFrame = CFrame.new(0, 80, spec.z - dir * 0.2), Color = Color3.fromRGB(120, 90, 40), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "ClockHour", Size = Vector3.new(0.8, 3.2, 0.25), CFrame = CFrame.new(0, 81.4, spec.z + dir * 0.35), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		part({ Name = "ClockMinute", Size = Vector3.new(0.6, 4.2, 0.25), CFrame = CFrame.new(1.3, 80.8, spec.z + dir * 0.36) * CFrame.Angles(0, 0, math.rad(-58)), Color = Color3.fromRGB(28, 30, 34), Parent = parent })
		local _ = face
	end

	-- school name over the entrance
	local sign = part({ Name = "FacadeSign", Size = Vector3.new(40, 5, 1.2), CFrame = CFrame.new(0, 39.6, Z + 12.2), Color = Color3.fromRGB(24, 32, 58), Parent = parent })
	signText(sign, "DETENTION", Color3.fromRGB(255, 196, 60), Enum.NormalId.Front)

	-- ---- corner towers with crenellations ----
	for _, corner in { { -224, 124 }, { 224, 124 }, { -224, -124 }, { 224, -124 } } do
		local cx, cz = corner[1], corner[2]
		tag(part({ Name = "CornerTower", Size = Vector3.new(32, 52, 32), CFrame = CFrame.new(cx, 26, cz), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
		trimBand(cx, 52.8, cz, 35, 35, 2.0)
		for i = 0, 5 do
			for _, edge in { { x = cx - 16 + i * 6.4, z = cz - 16 }, { x = cx - 16 + i * 6.4, z = cz + 16 }, { x = cx - 16, z = cz - 16 + i * 6.4 }, { x = cx + 16, z = cz - 16 + i * 6.4 } } do
				part({ Name = "Crenel", Size = Vector3.new(3.4, 3.4, 3.4), CFrame = CFrame.new(edge.x, 55.4, edge.z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent })
			end
		end
		-- arched windows up the tower
		for _, y in { 12, 26, 40 } do
			local w = part({ Name = "TowerWindow", Size = Vector3.new(5, 7, 0.6), CFrame = CFrame.new(cx, y, cz + (cz > 0 and 16.2 or -16.2)), Color = Color3.fromRGB(196, 224, 240), Material = Enum.Material.Glass, Transparency = 0.25, Parent = parent })
			tag(w, "TexWindow")
			trimBand(cx, y + 4, cz + (cz > 0 and 16.3 or -16.3), 6.4, 0.8, 0.8)
		end
	end

	-- ---- white trim banding along the long facades ----
	for _, spec in {
		{ z = Z + 1.2, len = 448 },
		{ z = -Z - 1.2, len = 448 },
	} do
		trimBand(0, 14.6, spec.z, spec.len, 2.6, 1.5)
		trimBand(0, 26.2, spec.z, spec.len, 2.6, 1.5)
	end
	for _, x in { -225.2, 225.2 } do
		part({ Name = "FacadeTrim", Size = Vector3.new(2.6, 1.5, 248), CFrame = CFrame.new(x, 14.6, 0), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "FacadeTrim", Size = Vector3.new(2.6, 1.5, 248), CFrame = CFrame.new(x, 26.2, 0), Color = TRIM, Material = Enum.Material.Concrete, Parent = parent })
	end

	-- ---- entrance plaza, lamps and planters ----
	part({ Name = "EntrancePlaza", Size = Vector3.new(120, 0.5, 46), CFrame = CFrame.new(0, 0.15, Z + 40), Color = Color3.fromRGB(186, 182, 174), Material = Enum.Material.Concrete, Parent = parent })
	tag(part({ Name = "PlazaWalk", Size = Vector3.new(26, 0.6, 34), CFrame = CFrame.new(0, 0.2, Z + 40), Color = Color3.fromRGB(206, 200, 190), Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
	for _, lx in { -54, -30, 30, 54 } do
		part({ Name = "WalkLampPost", Size = Vector3.new(0.9, 16, 0.9), CFrame = CFrame.new(lx, 8, Z + 34), Color = Color3.fromRGB(52, 56, 62), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "WalkLampHead", Size = Vector3.new(2.6, 3, 2.6), CFrame = CFrame.new(lx, 16.6, Z + 34), Color = Color3.fromRGB(255, 244, 214), Material = Enum.Material.Neon, Parent = parent })
		part({ Name = "WalkLampCap", Size = Vector3.new(3.4, 0.8, 3.4), CFrame = CFrame.new(lx, 18.4, Z + 34), Color = Color3.fromRGB(52, 56, 62), Material = Enum.Material.Metal, Parent = parent })
	end
	for _, px in { -44, 44 } do
		part({ Name = "Planter", Size = Vector3.new(10, 3.4, 10), CFrame = CFrame.new(px, 1.7, Z + 26), Color = Color3.fromRGB(176, 170, 160), Material = Enum.Material.Concrete, Parent = parent })
		part({ Name = "PlanterSoil", Size = Vector3.new(8.6, 0.6, 8.6), CFrame = CFrame.new(px, 3.5, Z + 26), Color = Color3.fromRGB(78, 58, 42), Material = Enum.Material.Ground, Parent = parent })
		part({ Name = "PlanterShrub", Size = Vector3.new(7, 5.4, 7), CFrame = CFrame.new(px, 6.4, Z + 26), Color = Color3.fromRGB(62, 116, 58), Material = Enum.Material.Grass, Parent = parent })
	end
	-- flower boxes under the ground-floor windows (the Reddit-street touch)
	for i = 0, 25 do
		local bx = -206 + i * 16.4
		if math.abs(bx) > 40 then
			part({ Name = "WindowBox", Size = Vector3.new(8, 1.6, 2.4), CFrame = CFrame.new(bx, 10.2, Z + 1.6), Color = Color3.fromRGB(104, 68, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
			for f = 0, 2 do
				part({ Name = "BoxBloom", Shape = Enum.PartType.Ball, Size = Vector3.new(1.9, 1.9, 1.9), CFrame = CFrame.new(bx - 2.4 + f * 2.4, 11.4, Z + 1.6), Color = f == 1 and Color3.fromRGB(226, 96, 108) or Color3.fromRGB(238, 176, 84), Material = Enum.Material.Grass, Parent = parent })
			end
		end
	end

	-- ---- hedges + lawn strip hugging the front ----
	for i = 0, 27 do
		local x = -210 + i * 15.5
		if math.abs(x) > 34 then
			part({ Name = "FrontHedge", Size = Vector3.new(13, 4.4, 6), CFrame = CFrame.new(x, 2.2, Z + 26), Color = Color3.fromRGB(58, 108, 56), Material = Enum.Material.Grass, Parent = parent })
		end
	end
	part({ Name = "FrontLawn", Size = Vector3.new(452, 0.5, 26), CFrame = CFrame.new(0, 0.12, Z + 40), Color = Color3.fromRGB(104, 162, 76), Material = Enum.Material.Grass, Parent = parent })
	-- flanking flag poles
	for _, fx in { -34, 34 } do
		part({ Name = "FlagPoleSmall", Size = Vector3.new(0.7, 22, 0.7), CFrame = CFrame.new(fx, 11, Z + 24), Color = Color3.fromRGB(198, 198, 202), Material = Enum.Material.Metal, Parent = parent })
		part({ Name = "FlagSmall", Size = Vector3.new(6, 3.6, 0.2), CFrame = CFrame.new(fx + 3.2, 19, Z + 24), Color = fx < 0 and Color3.fromRGB(196, 56, 56) or Color3.fromRGB(56, 96, 196), Material = Enum.Material.Fabric, Parent = parent })
	end
end

-- The campus front, built from the reference: a paved parking apron with
-- parked cars and a bus, bike racks, benches, a bronze statue on a plinth,
-- clipped hedge borders and tall conifers flanking the facade.
local function buildFrontGrounds(parent: Instance)
	local Z = 124
	local ASPHALT = Color3.fromRGB(64, 66, 72)
	local CURB = Color3.fromRGB(198, 194, 186)

	-- parking apron either side of the entrance plaza
	for _, sgn in { -1, 1 } do
		local px = sgn * 132
		part({ Name = "ParkingLot", Size = Vector3.new(120, 0.5, 62), CFrame = CFrame.new(px, 0.15, Z + 46), Color = ASPHALT, Material = Enum.Material.Asphalt, Parent = parent })
		part({ Name = "ParkingCurb", Size = Vector3.new(122, 1.1, 2), CFrame = CFrame.new(px, 0.5, Z + 15.4), Color = CURB, Material = Enum.Material.Concrete, Parent = parent })
		-- painted bays
		for i = 0, 7 do
			part({ Name = "ParkingLine", Size = Vector3.new(0.6, 0.15, 26), CFrame = CFrame.new(px - 56 + i * 15, 0.42, Z + 34), Color = Color3.fromRGB(232, 228, 210), Material = Enum.Material.SmoothPlastic, Parent = parent })
		end
		-- parked cars: body, cabin, wheels
		local carColors = {
			Color3.fromRGB(196, 62, 58), Color3.fromRGB(52, 96, 176),
			Color3.fromRGB(226, 226, 230), Color3.fromRGB(64, 148, 108),
			Color3.fromRGB(228, 176, 66),
		}
		for i = 0, 4 do
			local cx = px - 48 + i * 15
			local col = carColors[(i + (sgn > 0 and 2 or 0)) % #carColors + 1]
			part({ Name = "CarBody", Size = Vector3.new(7.4, 3.4, 15), CFrame = CFrame.new(cx, 2.4, Z + 34), Color = col, Material = Enum.Material.SmoothPlastic, Parent = parent })
			part({ Name = "CarCabin", Size = Vector3.new(6.8, 3.2, 7.6), CFrame = CFrame.new(cx, 5.4, Z + 34.6), Color = col, Material = Enum.Material.SmoothPlastic, Parent = parent })
			part({ Name = "CarGlass", Size = Vector3.new(6.9, 2.2, 6.4), CFrame = CFrame.new(cx, 5.8, Z + 34.6), Color = Color3.fromRGB(126, 158, 178), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
			for _, wz in { Z + 28.4, Z + 39.6 } do
				for _, wx in { cx - 3.5, cx + 3.5 } do
					part({ Name = "CarWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 2.8, 2.8), CFrame = CFrame.new(wx, 1.4, wz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(28, 28, 32), Material = Enum.Material.SmoothPlastic, Parent = parent })
				end
			end
			part({ Name = "CarLight", Size = Vector3.new(5.6, 0.8, 0.4), CFrame = CFrame.new(cx, 2.8, Z + 26.6), Color = Color3.fromRGB(255, 246, 214), Material = Enum.Material.Neon, Parent = parent })
		end
		-- lamp standards in the lot
		for _, lz in { Z + 26, Z + 60 } do
			part({ Name = "LotLampPost", Size = Vector3.new(1.1, 22, 1.1), CFrame = CFrame.new(px + 58, 11, lz), Color = Color3.fromRGB(72, 74, 80), Material = Enum.Material.Metal, Parent = parent })
			part({ Name = "LotLampArm", Size = Vector3.new(5, 0.8, 0.8), CFrame = CFrame.new(px + 55, 21.6, lz), Color = Color3.fromRGB(72, 74, 80), Material = Enum.Material.Metal, Parent = parent })
			part({ Name = "LotLampHead", Size = Vector3.new(3.4, 1, 2), CFrame = CFrame.new(px + 52.6, 21, lz), Color = Color3.fromRGB(255, 246, 220), Material = Enum.Material.Neon, Parent = parent })
		end
	end

	-- bike racks by the entrance
	for _, sgn in { -1, 1 } do
		local bx = sgn * 68
		part({ Name = "BikeRackBase", Size = Vector3.new(16, 0.5, 6), CFrame = CFrame.new(bx, 0.4, Z + 22), Color = Color3.fromRGB(150, 150, 156), Material = Enum.Material.Concrete, Parent = parent })
		for i = 0, 4 do
			part({ Name = "BikeHoop", Size = Vector3.new(0.5, 4.4, 0.5), CFrame = CFrame.new(bx - 6 + i * 3, 2.6, Z + 22), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent })
			part({ Name = "BikeHoopTop", Size = Vector3.new(0.5, 0.5, 4), CFrame = CFrame.new(bx - 6 + i * 3, 4.7, Z + 22), Color = Color3.fromRGB(96, 100, 108), Material = Enum.Material.Metal, Parent = parent })
		end
	end

	-- benches along the walk
	for _, sgn in { -1, 1 } do
		for _, bz in { Z + 30, Z + 46 } do
			local bx = sgn * 40
			part({ Name = "BenchSeat", Size = Vector3.new(3.4, 0.6, 12), CFrame = CFrame.new(bx, 2.4, bz), Color = Color3.fromRGB(146, 96, 56), Material = Enum.Material.WoodPlanks, Parent = parent })
			part({ Name = "BenchBack", Size = Vector3.new(0.6, 3.4, 12), CFrame = CFrame.new(bx + sgn * 1.4, 4.2, bz), Color = Color3.fromRGB(146, 96, 56), Material = Enum.Material.WoodPlanks, Parent = parent })
			for _, lz in { bz - 4.6, bz + 4.6 } do
				part({ Name = "BenchLeg", Size = Vector3.new(3.2, 2.2, 0.7), CFrame = CFrame.new(bx, 1.1, lz), Color = Color3.fromRGB(60, 62, 68), Material = Enum.Material.Metal, Parent = parent })
			end
		end
	end

	-- bronze founder statue on a stone plinth, centred on the walk
	local sz = Z + 44
	local sx = -56
	part({ Name = "StatuePlinthBase", Size = Vector3.new(14, 1.6, 14), CFrame = CFrame.new(sx, 0.9, sz), Color = Color3.fromRGB(178, 174, 166), Material = Enum.Material.Concrete, Parent = parent })
	part({ Name = "StatuePlinth", Size = Vector3.new(9, 8, 9), CFrame = CFrame.new(sx, 5.7, sz), Color = Color3.fromRGB(196, 192, 184), Material = Enum.Material.Marble, Parent = parent })
	part({ Name = "StatuePlinthCap", Size = Vector3.new(11, 1.2, 11), CFrame = CFrame.new(sx, 10.3, sz), Color = Color3.fromRGB(206, 202, 194), Material = Enum.Material.Marble, Parent = parent })
	local BRONZE = Color3.fromRGB(122, 92, 52)
	part({ Name = "StatueTorso", Size = Vector3.new(4, 6, 2.6), CFrame = CFrame.new(sx, 14, sz), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "StatueHead", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(sx, 18.2, sz), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "StatueArm", Size = Vector3.new(1.2, 5.4, 1.2), CFrame = CFrame.new(sx - 2.8, 15.2, sz) * CFrame.Angles(0, 0, math.rad(24)), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "StatueArmUp", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(sx + 2.9, 16.4, sz) * CFrame.Angles(0, 0, math.rad(-38)), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	for _, lx in { -1.1, 1.1 } do
		part({ Name = "StatueLeg", Size = Vector3.new(1.5, 5, 1.5), CFrame = CFrame.new(sx + lx, 8.4, sz), Color = BRONZE, Material = Enum.Material.Metal, Parent = parent })
	end
	local plaque = part({ Name = "StatuePlaque", Size = Vector3.new(6, 2.2, 0.4), CFrame = CFrame.new(sx, 6.4, sz - 4.7), Color = Color3.fromRGB(96, 74, 44), Material = Enum.Material.Metal, Parent = parent })
	signText(plaque, "CRUMBWORTH", Color3.fromRGB(238, 226, 196), Enum.NormalId.Front)

	-- clipped hedge borders around the lawns
	for _, sgn in { -1, 1 } do
		for i = 0, 7 do
			part({ Name = "BorderHedge", Size = Vector3.new(12, 3.6, 4.4), CFrame = CFrame.new(sgn * (74 + i * 0), 1.8, Z + 22 + i * 7), Color = Color3.fromRGB(54, 104, 52), Material = Enum.Material.Grass, Parent = parent })
			part({ Name = "BorderHedge", Size = Vector3.new(4.4, 3.6, 12), CFrame = CFrame.new(sgn * (34 + i * 6), 1.8, Z + 66), Color = Color3.fromRGB(54, 104, 52), Material = Enum.Material.Grass, Parent = parent })
		end
	end

	-- school sign board at the curb
	part({ Name = "SignPost", Size = Vector3.new(1.4, 8, 1.4), CFrame = CFrame.new(58, 4, Z + 64), Color = Color3.fromRGB(96, 62, 42), Material = Enum.Material.WoodPlanks, Parent = parent })
	part({ Name = "SignPost", Size = Vector3.new(1.4, 8, 1.4), CFrame = CFrame.new(82, 4, Z + 64), Color = Color3.fromRGB(96, 62, 42), Material = Enum.Material.WoodPlanks, Parent = parent })
	local board = part({ Name = "SchoolSignBoard", Size = Vector3.new(28, 9, 1.2), CFrame = CFrame.new(70, 11, Z + 64), Color = Color3.fromRGB(28, 44, 78), Material = Enum.Material.SmoothPlastic, Parent = parent })
	signText(board, "DETENTION\nCRUMBWORTH HIGH", Color3.fromRGB(255, 208, 96), Enum.NormalId.Front)
	part({ Name = "SignBoardTrim", Size = Vector3.new(29.4, 10.4, 0.6), CFrame = CFrame.new(70, 11, Z + 64.5), Color = Color3.fromRGB(232, 228, 218), Material = Enum.Material.Concrete, Parent = parent })
end


-- The main corridor, built from the locker-hallway reference: banks of
-- lockers with a few doors swung open and contents inside, water coolers,
-- trophy cases, recessed ceiling panels and a tiled floor band.
local function detailCorridor(parent: Instance)
	local LOCKER = Color3.fromRGB(46, 84, 168)
	local LOCKER_DARK = Color3.fromRGB(30, 58, 122)
	local rng = Random.new(91)
	for _, spec in {
		{ z = 79.6, face = -1, banks = { -196, -168, -140, -112, 112, 140, 168, 196 } },
		-- the north wall moved out with the widening, and the banks with it;
		-- past x = 172 there is no wall on this side any more, only the way
		-- through to the far rooms
		{ z = 50.4, face = 1, banks = { -160, -128, 128, 160 } },
	} do
		for _, bankX in spec.banks do
			for i = 0, 5 do
				local lx = bankX - 12 + i * 4.2
				local open = rng:NextNumber() < 0.22
				-- carcass
				part({ Name = "LockerBody", Size = Vector3.new(4, 9, 3), CFrame = CFrame.new(lx, 4.6, spec.z + spec.face * 1.4), Color = LOCKER_DARK, Material = Enum.Material.Metal, Parent = parent })
				if open then
					-- shelf + contents visible in the opening
					part({ Name = "LockerShelf", Size = Vector3.new(3.4, 0.3, 2.4), CFrame = CFrame.new(lx, 6.6, spec.z + spec.face * 1.4), Color = Color3.fromRGB(196, 196, 200), Material = Enum.Material.Metal, Parent = parent })
					part({ Name = "LockerBooks", Size = Vector3.new(2.4, 2.2, 1.6), CFrame = CFrame.new(lx, 2.2, spec.z + spec.face * 1.5), Color = rng:NextNumber() < 0.5 and Color3.fromRGB(178, 62, 58) or Color3.fromRGB(58, 118, 92), Material = Enum.Material.SmoothPlastic, Parent = parent })
					part({ Name = "LockerBottle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1, 1), CFrame = CFrame.new(lx + 0.9, 7.9, spec.z + spec.face * 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(232, 226, 214), Material = Enum.Material.SmoothPlastic, Parent = parent })
					-- door swung out into the corridor
					part({ Name = "LockerDoorOpen", Size = Vector3.new(3.9, 8.6, 0.35), CFrame = CFrame.new(lx - 1.9, 4.6, spec.z + spec.face * 4.2) * CFrame.Angles(0, math.rad(78) * spec.face, 0), Color = LOCKER, Material = Enum.Material.Metal, Parent = parent })
				else
					local door = part({ Name = "LockerDoor", Size = Vector3.new(3.9, 8.6, 0.4), CFrame = CFrame.new(lx, 4.6, spec.z + spec.face * 2.9), Color = LOCKER, Material = Enum.Material.Metal, Parent = parent })
					local _ = door
					-- vent slots + handle
					for v = 0, 2 do
						part({ Name = "LockerVent", Size = Vector3.new(2.6, 0.28, 0.5), CFrame = CFrame.new(lx, 7.6 + v * 0.6, spec.z + spec.face * 3.1), Color = LOCKER_DARK, Material = Enum.Material.Metal, Parent = parent })
					end
					part({ Name = "LockerHandle", Size = Vector3.new(0.4, 1.4, 0.5), CFrame = CFrame.new(lx + 1.4, 4.4, spec.z + spec.face * 3.1), Color = Color3.fromRGB(214, 214, 220), Material = Enum.Material.Metal, Parent = parent })
				end
			end
			-- bank top rail
			part({ Name = "LockerTop", Size = Vector3.new(26, 0.6, 3.4), CFrame = CFrame.new(bankX, 9.3, spec.z + spec.face * 1.6), Color = LOCKER_DARK, Material = Enum.Material.Metal, Parent = parent })
		end
		-- water coolers between banks
		for _, wx in { -110, 110 } do
			part({ Name = "CoolerBody", Size = Vector3.new(3, 5, 2.6), CFrame = CFrame.new(wx, 2.5, spec.z + spec.face * 1.4), Color = Color3.fromRGB(226, 228, 232), Material = Enum.Material.SmoothPlastic, Parent = parent })
			part({ Name = "CoolerBottle", Size = Vector3.new(2.4, 3.4, 2.4), CFrame = CFrame.new(wx, 6.7, spec.z + spec.face * 1.4), Color = Color3.fromRGB(150, 206, 226), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
		end
	end
	-- trophy cases flanking the lobby end
	for _, tx in { -74, 74 } do
		part({ Name = "TrophyCase", Size = Vector3.new(16, 10, 2.4), CFrame = CFrame.new(tx, 5.4, 79.4), Color = Color3.fromRGB(92, 60, 40), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "TrophyGlass", Size = Vector3.new(14.4, 7.6, 0.4), CFrame = CFrame.new(tx, 6, 78), Color = Color3.fromRGB(196, 226, 238), Material = Enum.Material.Glass, Transparency = 0.5, Parent = parent })
		for tI = 0, 3 do
			part({ Name = "Trophy", Size = Vector3.new(1.2, 2.4, 1.2), CFrame = CFrame.new(tx - 5 + tI * 3.4, 4.6, 78.8), Color = Color3.fromRGB(212, 176, 78), Material = Enum.Material.Metal, Parent = parent })
		end
	end
	-- recessed ceiling panels down the corridor
	for i = 0, 26 do
		part({ Name = "CeilingPanel", Size = Vector3.new(10, 0.3, 6), CFrame = CFrame.new(-208 + i * 16, 15.1, 65), Color = Color3.fromRGB(255, 250, 236), Material = Enum.Material.Neon, Parent = parent })
	end
	-- tiled centre band on the floor
	tag(part({ Name = "CorridorTileBand", Size = Vector3.new(440, 0.12, 10), CFrame = CFrame.new(0, 0.08, 65), Color = Color3.fromRGB(212, 208, 198), Material = Enum.Material.CeramicTiles, Parent = parent }), "TexFloorTile")
end

-- ================= THE UPPER FLOOR =================
-- The school always looked like three storeys from the outside -- the facade
-- has three bands of windows -- and was one storey deep. This is the second,
-- built into the band the facade already draws: floor at y = 16, walls to
-- 31.6, which is exactly the height buildInteriorWall makes when it is handed
-- a base at that level.
--
-- The plan is a ring. South rooms, the upper hall over the main hallway, a
-- wing down each side and a north row, with the whole middle left open: you
-- come up the stairs and the atrium and both courtyards fall away beneath
-- you. A second storey that is merely more corridor is not worth climbing.
local UPPER_Y = 16
local UPPER_CEIL = 31.6

-- Each entry is a floor rectangle {x0, z0, x1, z1}. The holes -- the atrium,
-- the courtyards, the gym, the lobby light well and the four stair wells --
-- are cut by leaving them out, which is why the south band is in pieces.
local UPPER_SLABS = {
	-- south band, around the lobby light well and the two lobby stairs
	{ -224, 81, -52, 124 },
	{ -52, 81, -40, 84 },
	{ -52, 118, -40, 124 },
	{ -40, 81, -34, 124 },
	{ -34, 81, 34, 88 },
	{ -34, 118, 34, 124 },
	{ 34, 81, 40, 124 },
	{ 40, 81, 52, 84 },
	{ 40, 118, 52, 124 },
	{ 52, 81, 224, 124 },
	-- the upper hall, straight across over the main hallway
	{ -224, 49, 224, 81 },
	-- west wing, around its stair well
	{ -224, -64, -202, 49 },
	{ -202, -64, -190, -22 },
	{ -202, 10, -190, 49 },
	{ -190, -64, -172, 49 },
	-- east wing, mirrored
	{ 172, -64, 190, 49 },
	{ 190, -64, 202, -22 },
	{ 190, 10, 202, 49 },
	{ 202, -64, 224, 49 },
	-- north band, open over the gym
	{ -224, -124, -50, -64 },
	{ 50, -124, 224, -64 },
}

-- Where the void edges are, so a railing can run along each one.
local UPPER_RAILS = {
	{ -172, 49, 172, 49 }, -- the long inner edge over the courtyards
	{ -60, -64, 60, -64 }, -- over the gym doors
	{ -172, -64, -172, 49 },
	{ 172, -64, 172, 49 },
	{ -50, -124, -50, -64 }, -- the gym well
	{ 50, -124, 50, -64 },
	{ -34, 88, 34, 88 }, -- the lobby light well
	{ -34, 118, 34, 118 },
	{ -34, 88, -34, 118 },
	{ 34, 88, 34, 118 },
}

-- The rooms upstairs. The five timetabled subjects stay on the ground floor
-- where the professors are; these are the rest of a school, and each one is
-- built around a single idea rather than being a room with desks in it.
export type UpperRoom = {
	name: string,
	label: string,
	icon: string,
	center: Vector3,
	size: Vector2,
	color: Color3,
	floor: Color3,
}

local UPPER_ROOMS: { UpperRoom } = {
	{ name = "ArtRoom", label = "ART", icon = "🎨", center = Vector3.new(-190, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(236, 132, 88), floor = Color3.fromRGB(176, 122, 88) },
	{ name = "HistoryRoom", label = "HISTORY", icon = "🏛️", center = Vector3.new(-122, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(190, 158, 96), floor = Color3.fromRGB(122, 92, 64) },
	{ name = "ComputerLab", label = "COMPUTER LAB", icon = "💻", center = Vector3.new(122, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(104, 176, 226), floor = Color3.fromRGB(70, 78, 92) },
	{ name = "LanguageLab", label = "LANGUAGES", icon = "🗣️", center = Vector3.new(190, UPPER_Y, 103), size = Vector2.new(52, 38), color = Color3.fromRGB(140, 200, 150), floor = Color3.fromRGB(126, 130, 120) },
	{ name = "StudyHall", label = "STUDY HALL", icon = "📖", center = Vector3.new(-190, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(196, 176, 216), floor = Color3.fromRGB(120, 96, 130) },
	{ name = "DramaStudio", label = "DRAMA", icon = "🎭", center = Vector3.new(-122, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(214, 96, 120), floor = Color3.fromRGB(78, 60, 72) },
	{ name = "Infirmary", label = "NURSE", icon = "🏥", center = Vector3.new(122, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(232, 240, 244), floor = Color3.fromRGB(206, 224, 226) },
	{ name = "StaffRoom", label = "STAFF ROOM", icon = "☕", center = Vector3.new(190, UPPER_Y, -94), size = Vector2.new(52, 52), color = Color3.fromRGB(150, 140, 128), floor = Color3.fromRGB(126, 104, 84) },
}

-- A flight of stairs as solid blocks: each tread is a box from the ground to
-- its own top, so there is no gap to fall through and no invisible ramp to
-- disagree with what you can see. `base` sits at the foot and looks up the
-- flight, so the climb runs along its LookVector -- local -Z, which is why
-- every offset here is negative in Z.
local function buildStair(parent: Instance, base: CFrame, steps: number, rise: number, run: number, width: number)
	for i = 0, steps - 1 do
		local top = (i + 1) * rise
		part({
			Name = "StairTread",
			Size = Vector3.new(width, top, run),
			CFrame = base * CFrame.new(0, top / 2, -(i + 0.5) * run),
			Color = Color3.fromRGB(214, 208, 196),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end
	local length = steps * run
	local climb = steps * rise
	for _, side in { -1, 1 } do
		-- a stringer and a rail, so the flight reads as built rather than
		-- as a stack of boxes
		local stringer = part({
			Name = "StairStringer",
			Size = Vector3.new(1.2, 2.4, math.sqrt(length * length + climb * climb)),
			CFrame = base
				* CFrame.new(side * (width / 2 + 0.5), climb / 2, -length / 2)
				* CFrame.Angles(math.atan2(climb, length), 0, 0),
			Color = Color3.fromRGB(120, 84, 58),
			Material = Enum.Material.WoodPlanks,
			Parent = parent,
		})
		stringer.CanCollide = false
		local rail = part({
			Name = "StairRail",
			Size = Vector3.new(0.5, 0.5, math.sqrt(length * length + climb * climb)),
			CFrame = base
				* CFrame.new(side * (width / 2 + 0.5), climb / 2 + 3.4, -length / 2)
				* CFrame.Angles(math.atan2(climb, length), 0, 0),
			Color = Color3.fromRGB(226, 220, 208),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		rail.CanCollide = false
	end
end

local function buildRailing(parent: Instance, from: Vector3, to: Vector3)
	local dir = to - from
	local length = dir.Magnitude
	if length < 1 then
		return
	end
	local mid = from + dir * 0.5
	local cf = CFrame.lookAt(mid, mid + Vector3.new(-dir.Unit.Z, 0, dir.Unit.X))
	part({ Name = "BalconyKick", Size = Vector3.new(length, 1.6, 1.2), CFrame = cf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(226, 222, 210), Material = Enum.Material.Concrete, Parent = parent })
	local top = part({ Name = "BalconyRail", Size = Vector3.new(length, 0.7, 1.4), CFrame = cf * CFrame.new(0, 5.2, 0), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
	top.CanCollide = true
	local balusters = math.max(2, math.floor(length / 3.2))
	for i = 0, balusters do
		local at = -length / 2 + (length / balusters) * i
		local post = part({ Name = "Baluster", Size = Vector3.new(0.4, 3.4, 0.4), CFrame = cf * CFrame.new(at, 3.3, 0), Color = Color3.fromRGB(206, 200, 188), Material = Enum.Material.Metal, Parent = parent })
		post.CanCollide = false
	end
	-- an invisible wall so nobody walks between the balusters
	local guard = part({ Name = "BalconyGuard", Size = Vector3.new(length, 5.4, 1), CFrame = cf * CFrame.new(0, 2.7, 0), Color = Color3.fromRGB(226, 222, 210), Parent = parent })
	guard.Transparency = 1
	guard.CanCollide = true
end

local function buildUpperFloor(parent: Instance)
	-- ---- the deck ----
	for index, rect in UPPER_SLABS do
		local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
		tag(part({
			Name = "UpperFloor" .. index,
			Size = Vector3.new(x1 - x0, 1, z1 - z0),
			CFrame = CFrame.new((x0 + x1) / 2, UPPER_Y - 0.5, (z0 + z1) / 2),
			Color = Color3.fromRGB(196, 194, 188),
			Parent = parent,
		}), "TexFloorTile")
		-- the underside is the ground floor's ceiling, which it never had
		tag(part({
			Name = "UpperSoffit" .. index,
			Size = Vector3.new(x1 - x0, 0.6, z1 - z0),
			CFrame = CFrame.new((x0 + x1) / 2, UPPER_Y - 1.3, (z0 + z1) / 2),
			Color = Color3.fromRGB(238, 234, 224),
			Parent = parent,
		}), "TexCeiling")
		-- and a ceiling over the upper floor itself
		tag(part({
			Name = "UpperCeiling" .. index,
			Size = Vector3.new(x1 - x0, 0.8, z1 - z0),
			CFrame = CFrame.new((x0 + x1) / 2, UPPER_CEIL, (z0 + z1) / 2),
			Color = Color3.fromRGB(240, 236, 226),
			Parent = parent,
		}), "TexCeiling")
	end

	-- ---- the edges you can fall off ----
	for _, rail in UPPER_RAILS do
		buildRailing(parent, Vector3.new(rail[1], UPPER_Y, rail[2]), Vector3.new(rail[3], UPPER_Y, rail[4]))
	end

	-- ---- getting up there ----
	-- two grand flights out of the lobby, one in each wing. 16 treads of 1 by
	-- 1.8 is a climb Roblox's step height takes without a stutter.
	for _, sx in { -46, 46 } do
		buildStair(parent, CFrame.lookAt(Vector3.new(sx, 0, 117.2), Vector3.new(sx, 0, 90)), 16, 1, 1.8, 10)
	end
	for _, sx in { -196, 196 } do
		buildStair(parent, CFrame.lookAt(Vector3.new(sx, 0, -21.2), Vector3.new(sx, 0, 6)), 16, 1, 1.8, 10)
	end

	-- ---- the rooms ----
	for _, room in UPPER_ROOMS do
		local halfX, halfZ = room.size.X / 2, room.size.Y / 2
		tag(part({
			Name = room.name .. "Floor",
			Size = Vector3.new(room.size.X, 0.4, room.size.Y),
			CFrame = CFrame.new(room.center) * CFrame.new(0, 0.2, 0),
			Color = room.floor,
			Material = Enum.Material.Carpet,
			Parent = parent,
		}), "TexCarpet")

		-- the wall onto the hall, with the door in it, then the two sides
		local hallSide = if room.center.Z > 0 then -1 else 1
		local front = room.center.Z + hallSide * halfZ
		buildInteriorWall(
			parent,
			Vector3.new(room.center.X - halfX, UPPER_Y, front),
			Vector3.new(room.center.X + halfX, UPPER_Y, front),
			{ { at = halfX, width = 14 } }
		)
		for _, side in { -1, 1 } do
			buildInteriorWall(
				parent,
				Vector3.new(room.center.X + side * halfX, UPPER_Y, room.center.Z - halfZ),
				Vector3.new(room.center.X + side * halfX, UPPER_Y, room.center.Z + halfZ),
				{}
			)
		end

        -- The sign hangs over the door, out in the hall, double sided and lit.
		-- Finding a room should not require walking into it.
		local sign = part({
			Name = room.name .. "Sign",
			Size = Vector3.new(22, 4.4, 0.6),
			CFrame = CFrame.new(room.center.X, UPPER_Y + 12.6, front + hallSide * 2.4),
			Color = Palette.Blackboard,
			Parent = parent,
		})
		sign.CanCollide = false
		signText(sign, room.icon .. " " .. room.label, room.color, Enum.NormalId.Front)
		signText(sign, room.icon .. " " .. room.label, room.color, Enum.NormalId.Back)
		local glow = Instance.new("SurfaceLight")
		glow.Face = if hallSide < 0 then Enum.NormalId.Front else Enum.NormalId.Back
		glow.Range = 22
		glow.Brightness = 1.4
		glow.Color = room.color
		glow.Parent = sign
	end
end

-- ================= THE SUBJECT ROOMS =================
-- Five timetabled subjects, five rooms, and each one built around what
-- happens in it rather than being a box with desks in it. A player should be
-- able to stand in a doorway and know which lesson they walked into.
--
-- Room boxes, from the plan above:
--   Room 101 (Maths)     x -88..-60   z -124..-64
--   Music Room           x  60..88    z -124..-64
--   Greenhouse (Bio)     x -134..-98  z  -45..-11
--   East Lab (Chemistry) x  98..134   z  -45..-11
--   Gym                  x -50..50    z -146..-64

local function furnishSubjectRooms(parent: Instance)
	-- ---------------- Room 101: Mathematics ----------------
	do
		local cx = -74
		prop("OfficeDesk", CFrame.new(cx, 0, -116))
		prop("Laptop", CFrame.new(cx, 2.9, -116))
		prop("Notepads", CFrame.new(cx + 3.2, 2.9, -116))
		prop("Bookshelf", CFrame.new(-86, 0, -110) * CFrame.Angles(0, math.rad(90), 0))
		prop("SteelShelves2", CFrame.new(-86, 0, -76) * CFrame.Angles(0, math.rad(90), 0))
		prop("Bin", CFrame.new(-63, 0, -70))
		prop("Extinguisher", CFrame.new(-63, 0, -114))
		prop("PottedPlant", CFrame.new(-86, 0, -70))
		prop("Clock", CFrame.new(cx, 11, -120.4))

		-- the wall of shapes: a maths room says what it is with geometry
		local shapes = {
			{ shape = Enum.PartType.Cylinder, size = Vector3.new(0.6, 7, 7), color = Color3.fromRGB(228, 96, 88), z = -108 },
			{ shape = Enum.PartType.Block, size = Vector3.new(0.6, 6, 6), color = Color3.fromRGB(96, 160, 228), z = -98 },
			{ shape = Enum.PartType.Ball, size = Vector3.new(6, 6, 6), color = Color3.fromRGB(246, 200, 74), z = -88 },
		}
		for _, spec in shapes do
			local piece = part({
				Name = "MathShape",
				Shape = spec.shape,
				Size = spec.size,
				CFrame = CFrame.new(-87.2, 9, spec.z) * (spec.shape == Enum.PartType.Cylinder and CFrame.Angles(0, 0, 0) or CFrame.new()),
				Color = spec.color,
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			})
			piece.CanCollide = false
		end
		-- a number line down the east wall, which is the one thing every
		-- maths room in the world actually has
		for i = 0, 10 do
			local tile = part({
				Name = "NumberTile",
				Size = Vector3.new(0.4, 2.4, 2.4),
				CFrame = CFrame.new(-60.9, 10, -114 + i * 4.4),
				Color = i % 2 == 0 and Color3.fromRGB(244, 242, 236) or Color3.fromRGB(96, 160, 228),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			})
			tile.CanCollide = false
			signText(tile, tostring(i), i % 2 == 0 and Color3.fromRGB(40, 44, 56) or Color3.fromRGB(255, 255, 255), Enum.NormalId.Left)
		end
		-- an abacus on a stand by the board
		local frame = part({ Name = "AbacusFrame", Size = Vector3.new(9, 7, 0.8), CFrame = CFrame.new(-66, 5.5, -119), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
		frame.CanCollide = false
		for row = 0, 3 do
			part({ Name = "AbacusRod", Size = Vector3.new(8, 0.2, 0.2), CFrame = CFrame.new(-66, 3.2 + row * 1.5, -118.6), Color = Color3.fromRGB(200, 196, 186), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			for bead = 0, 6 do
				local ball = part({
					Name = "AbacusBead",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.9, 0.9, 0.9),
					CFrame = CFrame.new(-69.4 + bead * 1.15, 3.2 + row * 1.5, -118.6),
					Color = row % 2 == 0 and Color3.fromRGB(228, 96, 88) or Color3.fromRGB(96, 160, 228),
					Parent = parent,
				})
				ball.CanCollide = false
			end
		end
	end

	-- ---------------- the Music Room ----------------
	do
		local cx = 74
		-- a grand piano: case, lid on its stick, keyboard, three legs, bench
		local case = part({ Name = "PianoCase", Size = Vector3.new(11, 3.2, 15), CFrame = CFrame.new(cx, 4.2, -112), Color = Color3.fromRGB(22, 22, 26), Material = Enum.Material.SmoothPlastic, Parent = parent })
		local _ = case
		part({ Name = "PianoLid", Size = Vector3.new(11, 0.5, 15), CFrame = CFrame.new(cx - 1.8, 7.4, -112) * CFrame.Angles(0, 0, math.rad(-22)), Color = Color3.fromRGB(28, 28, 34), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "PianoStick", Size = Vector3.new(0.3, 4.4, 0.3), CFrame = CFrame.new(cx + 4.6, 7.6, -108) * CFrame.Angles(math.rad(8), 0, 0), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.Wood, Parent = parent })
		for i = 0, 21 do
			part({ Name = "PianoKeyWhite", Size = Vector3.new(0.5, 0.4, 3.4), CFrame = CFrame.new(cx - 5.4 + i * 0.52, 5.9, -104.4), Color = Color3.fromRGB(248, 246, 240), Material = Enum.Material.SmoothPlastic, Parent = parent }).CanCollide = false
			if i % 7 ~= 2 and i % 7 ~= 6 then
				part({ Name = "PianoKeyBlack", Size = Vector3.new(0.3, 0.5, 2.1), CFrame = CFrame.new(cx - 5.15 + i * 0.52, 6.2, -105.1), Color = Color3.fromRGB(18, 18, 22), Material = Enum.Material.SmoothPlastic, Parent = parent }).CanCollide = false
			end
		end
		for _, leg in { { -4.4, -118 }, { 4.4, -118 }, { 0, -105 } } do
			part({ Name = "PianoLeg", Size = Vector3.new(0.9, 2.6, 0.9), CFrame = CFrame.new(cx + leg[1], 1.3, leg[2]), Color = Color3.fromRGB(22, 22, 26), Material = Enum.Material.SmoothPlastic, Parent = parent })
		end
		part({ Name = "PianoBench", Size = Vector3.new(5, 0.6, 2), CFrame = CFrame.new(cx, 2.6, -101), Color = Color3.fromRGB(60, 40, 34), Material = Enum.Material.Fabric, Parent = parent })
		for _, bx in { -2, 2 } do
			part({ Name = "PianoBenchLeg", Size = Vector3.new(0.4, 2.3, 1.6), CFrame = CFrame.new(cx + bx, 1.15, -101), Color = Color3.fromRGB(22, 22, 26), Parent = parent })
		end

		-- risers, so a choir has somewhere to stand
		for step = 0, 2 do
			part({
				Name = "MusicRiser",
				Size = Vector3.new(24, 1.2 + step * 1.2, 5),
				CFrame = CFrame.new(cx, (1.2 + step * 1.2) / 2, -92 + step * 5),
				Color = Color3.fromRGB(96, 70, 54),
				Material = Enum.Material.WoodPlanks,
				Parent = parent,
			})
		end
		-- music stands in a row in front of them
		for i = 0, 5 do
			local sx = cx - 10 + i * 4
			part({ Name = "StandPole", Size = Vector3.new(0.25, 4.4, 0.25), CFrame = CFrame.new(sx, 2.2, -78), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "StandTray", Size = Vector3.new(3, 0.2, 2.2), CFrame = CFrame.new(sx, 4.7, -78.4) * CFrame.Angles(math.rad(-58), 0, 0), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "StandFoot", Size = Vector3.new(1.8, 0.2, 1.8), CFrame = CFrame.new(sx, 0.1, -78), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		end
		-- a stave painted across the wall, with notes on it
		for line = 0, 4 do
			part({ Name = "StaveLine", Size = Vector3.new(0.3, 0.25, 24), CFrame = CFrame.new(88.8, 8 + line * 1.4, -96), Color = Color3.fromRGB(40, 44, 56), Parent = parent }).CanCollide = false
		end
		for i, note in { 0, 2, 1, 3, 2, 4 } do
			local head = part({ Name = "StaveNote", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(88.6, 8 + note * 1.4, -106 + i * 3.6), Color = Color3.fromRGB(40, 44, 56), Parent = parent })
			head.CanCollide = false
			part({ Name = "StaveStem", Size = Vector3.new(0.25, 4, 0.25), CFrame = CFrame.new(88.6, 10 + note * 1.4, -105.4 + i * 3.6), Color = Color3.fromRGB(40, 44, 56), Parent = parent }).CanCollide = false
		end
		prop("Bookshelf", CFrame.new(62, 0, -110) * CFrame.Angles(0, math.rad(-90), 0))
		prop("Boombox", CFrame.new(62.5, 3.2, -76) * CFrame.Angles(0, math.rad(-90), 0))
		prop("Bin", CFrame.new(63, 0, -70))
		prop("Clock", CFrame.new(cx, 11, -120.4))
	end

	-- ---------------- the East Lab: Chemistry ----------------
	do
		local cx, cz = 116, -28
		-- three benches with black tops, a sink and a tap in each
		for row = 0, 2 do
			local bz = cz - 10 + row * 9
			part({ Name = "LabBench", Size = Vector3.new(26, 3, 4), CFrame = CFrame.new(cx, 1.5, bz), Color = Color3.fromRGB(206, 202, 194), Material = Enum.Material.SmoothPlastic, Parent = parent })
			part({ Name = "LabBenchTop", Size = Vector3.new(27, 0.5, 5), CFrame = CFrame.new(cx, 3.2, bz), Color = Color3.fromRGB(34, 36, 42), Material = Enum.Material.Slate, Parent = parent })
			part({ Name = "LabSink", Size = Vector3.new(3.4, 0.4, 2.6), CFrame = CFrame.new(cx + 10, 3.3, bz), Color = Color3.fromRGB(180, 186, 192), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "LabTap", Size = Vector3.new(0.3, 2.2, 0.3), CFrame = CFrame.new(cx + 10, 4.5, bz - 1.4), Color = Color3.fromRGB(200, 206, 212), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			prop("BunsenBurner", CFrame.new(cx - 8, 3.5, bz))
			prop("BunsenBurner", CFrame.new(cx - 2, 3.5, bz))
			-- glassware: a flask and two beakers per bench
			local flask = part({ Name = "LabFlask", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(cx + 3, 4.4, bz), Color = Color3.fromRGB(196, 232, 240), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
			flask.CanCollide = false
			part({ Name = "LabFlaskNeck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.7, 0.7), CFrame = CFrame.new(cx + 3, 6, bz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(196, 232, 240), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent }).CanCollide = false
			for i, tint in { Color3.fromRGB(120, 230, 160), Color3.fromRGB(230, 140, 200) } do
				local beaker = part({ Name = "LabBeaker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1.5, 1.5), CFrame = CFrame.new(cx + 5.5 + i * 2, 4.4, bz) * CFrame.Angles(0, 0, math.rad(90)), Color = tint, Material = Enum.Material.Glass, Transparency = 0.3, Parent = parent })
				beaker.CanCollide = false
			end
		end
		-- fume cupboard against the back wall
		part({ Name = "FumeHood", Size = Vector3.new(12, 10, 4), CFrame = CFrame.new(cx - 10, 5, cz - 14.4), Color = Color3.fromRGB(214, 216, 220), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "FumeGlass", Size = Vector3.new(10.4, 4.6, 0.4), CFrame = CFrame.new(cx - 10, 6, cz - 12.3), Color = Color3.fromRGB(196, 232, 240), Material = Enum.Material.Glass, Transparency = 0.4, Parent = parent }).CanCollide = false
		-- the periodic table, as an actual grid of tiles
		for col = 0, 8 do
			for row = 0, 5 do
				local tile = part({
					Name = "ElementTile",
					Size = Vector3.new(2, 2, 0.3),
					CFrame = CFrame.new(cx + 5 + (col - 4) * 2.2, 12 - row * 2.2, cz - 16.6),
					Color = Color3.fromRGB(80 + col * 16, 150 + row * 12, 220 - col * 14),
					Material = Enum.Material.SmoothPlastic,
					Parent = parent,
				})
				tile.CanCollide = false
			end
		end
		-- safety kit, because a chemistry room without it reads as a kitchen
		part({ Name = "SafetyShowerPipe", Size = Vector3.new(0.4, 9, 0.4), CFrame = CFrame.new(cx + 15, 4.5, cz + 12), Color = Color3.fromRGB(206, 210, 214), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		part({ Name = "SafetyShowerHead", Size = Vector3.new(3, 0.4, 3), CFrame = CFrame.new(cx + 15, 9, cz + 12), Color = Color3.fromRGB(230, 178, 40), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		local hazard = part({ Name = "HazardSign", Size = Vector3.new(5, 5, 0.3), CFrame = CFrame.new(cx - 15, 9, cz - 16.6), Color = Color3.fromRGB(246, 200, 48), Parent = parent })
		hazard.CanCollide = false
		signText(hazard, "⚠", Color3.fromRGB(30, 30, 34), Enum.NormalId.Front)
		prop("Extinguisher", CFrame.new(cx + 16, 0, cz - 13))
		prop("Bin", CFrame.new(cx - 16, 0, cz + 13))
		prop("SteelShelves", CFrame.new(cx - 16, 0, cz) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- ---------------- the Greenhouse: Biology, outdoors ----------------
	-- The brief for this one is "outdoor". It is a glasshouse, so the floor
	-- becomes ground and beds, not tile, and everything in it is alive.
	do
		local cx, cz = -116, -28
		tag(part({
			Name = "GreenhouseGround",
			Size = Vector3.new(34, 0.6, 32),
			CFrame = CFrame.new(cx, 0.35, cz),
			Color = Color3.fromRGB(96, 148, 74),
			Material = Enum.Material.Grass,
			Parent = parent,
		}), "TexGround")
		-- a path through the middle so the beds are reachable
		part({ Name = "GreenhousePath", Size = Vector3.new(7, 0.3, 32), CFrame = CFrame.new(cx, 0.7, cz), Color = Color3.fromRGB(178, 162, 132), Material = Enum.Material.Sand, Parent = parent })

		-- raised beds down both sides, planted
		for _, side in { -1, 1 } do
			for row = 0, 2 do
				local bx = cx + side * 10
				local bz = cz - 10 + row * 10
				part({ Name = "BedFrame", Size = Vector3.new(9, 2, 8), CFrame = CFrame.new(bx, 1, bz), Color = Color3.fromRGB(126, 92, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
				part({ Name = "BedSoil", Size = Vector3.new(8, 0.6, 7), CFrame = CFrame.new(bx, 2.1, bz), Color = Color3.fromRGB(74, 54, 38), Material = Enum.Material.Ground, Parent = parent }).CanCollide = false
				prop("Fern", CFrame.new(bx - 2.2, 2.4, bz))
				prop("Flowers", CFrame.new(bx + 2.2, 2.4, bz - 1.6))
				prop("Shrub", CFrame.new(bx + side * 2.6, 2.4, bz + 1.8))
			end
		end

		-- a pond at the north end with lilies in it
		part({ Name = "PondRim", Size = Vector3.new(13, 1.4, 9), CFrame = CFrame.new(cx, 0.7, cz - 13), Color = Color3.fromRGB(140, 136, 126), Material = Enum.Material.Slate, Parent = parent })
		local water = part({ Name = "PondWater", Size = Vector3.new(11.4, 0.8, 7.4), CFrame = CFrame.new(cx, 1.1, cz - 13), Color = Color3.fromRGB(78, 140, 158), Material = Enum.Material.Glass, Transparency = 0.28, Parent = parent })
		water.CanCollide = false
		for i, spot in { { -3, -1 }, { 1, 1.6 }, { 3.4, -1.8 } } do
			local pad = part({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.6, 2.6), CFrame = CFrame.new(cx + spot[1], 1.6, cz - 13 + spot[2]) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(76, 150, 74), Material = Enum.Material.Grass, Parent = parent })
			pad.CanCollide = false
			if i == 2 then
				part({ Name = "LilyFlower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(cx + spot[1], 2.2, cz - 13 + spot[2]), Color = Color3.fromRGB(240, 180, 210), Parent = parent }).CanCollide = false
			end
		end

		-- a potting bench, and the tools that belong on it
		part({ Name = "PottingBench", Size = Vector3.new(10, 0.5, 3.4), CFrame = CFrame.new(cx, 3.2, cz + 13), Color = Color3.fromRGB(140, 104, 68), Material = Enum.Material.WoodPlanks, Parent = parent })
		for _, lx in { -4.4, 4.4 } do
			part({ Name = "PottingLeg", Size = Vector3.new(0.6, 3.2, 3), CFrame = CFrame.new(cx + lx, 1.6, cz + 13), Color = Color3.fromRGB(126, 92, 58), Material = Enum.Material.Wood, Parent = parent })
		end
		prop("SeedingTray", CFrame.new(cx - 3, 3.5, cz + 13))
		prop("WateringCanMetal", CFrame.new(cx + 1, 3.5, cz + 13))
		prop("GardenGloves", CFrame.new(cx + 3.4, 3.5, cz + 13))
		prop("PlanterPot", CFrame.new(cx - 14, 0.7, cz + 13))
		prop("PlanterBox", CFrame.new(cx + 14, 0.7, cz + 13))

		-- trellises up the glass, and a tree the roof is built around
		for _, side in { -1, 1 } do
			for i = 0, 5 do
				part({ Name = "Trellis", Size = Vector3.new(0.3, 12, 0.3), CFrame = CFrame.new(cx + side * 16, 6, cz - 12 + i * 5), Color = Color3.fromRGB(150, 116, 76), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
			end
			for i = 0, 3 do
				part({ Name = "TrellisVine", Size = Vector3.new(0.5, 0.5, 30), CFrame = CFrame.new(cx + side * 15.7, 3 + i * 3, cz), Color = Color3.fromRGB(72, 128, 62), Material = Enum.Material.Grass, Parent = parent }).CanCollide = false
			end
		end
		part({ Name = "GreenhouseTrunk", Size = Vector3.new(2.4, 13, 2.4), CFrame = CFrame.new(cx, 6.5, cz + 6.5), Color = Color3.fromRGB(104, 78, 52), Material = Enum.Material.Wood, Parent = parent })
		for i = 0, 2 do
			part({
				Name = "GreenhouseCanopy",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(13 - i * 2.5, 7 - i, 13 - i * 2.5),
				CFrame = CFrame.new(cx, 12 + i * 2.4, cz + 6.5),
				Color = Color3.fromRGB(70 + i * 10, 132 + i * 12, 62),
				Material = Enum.Material.Grass,
				Parent = parent,
			}).CanCollide = false
		end
		-- hanging baskets from the ridge
		for _, hz in { cz - 6, cz + 8 } do
			part({ Name = "BasketChain", Size = Vector3.new(0.2, 4, 0.2), CFrame = CFrame.new(cx - 6, 15, hz), Color = Color3.fromRGB(180, 176, 168), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
			part({ Name = "HangingBasket", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3, 4), CFrame = CFrame.new(cx - 6, 12.4, hz), Color = Color3.fromRGB(86, 148, 70), Material = Enum.Material.Grass, Parent = parent }).CanCollide = false
		end
	end

	-- ---------------- the Gym ----------------
	do
		-- bleachers down both flanks
		for _, side in { -1, 1 } do
			for tier = 0, 3 do
				part({
					Name = "Bleacher",
					Size = Vector3.new(4, 2.4 + tier * 2.4, 60),
					CFrame = CFrame.new(side * (46 - tier * 4), (2.4 + tier * 2.4) / 2, -100),
					Color = tier % 2 == 0 and Color3.fromRGB(146, 100, 62) or Color3.fromRGB(122, 84, 52),
					Material = Enum.Material.WoodPlanks,
					Parent = parent,
				})
			end
		end
		-- a scoreboard on the north wall
		local board = part({ Name = "Scoreboard", Size = Vector3.new(26, 12, 1.2), CFrame = CFrame.new(0, 20, -144.4), Color = Color3.fromRGB(24, 26, 32), Parent = parent })
		board.CanCollide = false
		signText(board, "HOME  00 : 00  AWAY", Color3.fromRGB(255, 96, 72), Enum.NormalId.Front)
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Front
		glow.Range = 30
		glow.Brightness = 1.2
		glow.Color = Color3.fromRGB(255, 120, 90)
		glow.Parent = board
		-- climbing ropes and wall bars, the two things every gym has
		for _, rx in { -30, -18, 18, 30 } do
			part({ Name = "ClimbRope", Size = Vector3.new(0.5, 22, 0.5), CFrame = CFrame.new(rx, 13, -132), Color = Color3.fromRGB(206, 184, 140), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		end
		for bar = 0, 7 do
			part({ Name = "WallBar", Size = Vector3.new(0.8, 0.8, 14), CFrame = CFrame.new(-49, 3 + bar * 2.2, -76), Color = Color3.fromRGB(196, 158, 104), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
		end
		-- banners for the houses
		for i, tint in {
			Color3.fromRGB(214, 72, 64), Color3.fromRGB(72, 128, 214),
			Color3.fromRGB(238, 190, 60), Color3.fromRGB(84, 178, 108),
		} do
			part({
				Name = "GymBanner",
				Size = Vector3.new(0.4, 14, 7),
				CFrame = CFrame.new(49, 22, -126 + (i - 1) * 12),
				Color = tint,
				Material = Enum.Material.Fabric,
				Parent = parent,
			}).CanCollide = false
		end
		prop("Football", CFrame.new(-22, 0, -98))
		prop("AmericanFootball", CFrame.new(14, 0, -112))
		prop("Baseball", CFrame.new(4, 0, -90))
	end
end


-- Each upper room dressed for what it is. The rule is the same as downstairs:
-- one strong idea per room, built rather than labelled, so you know where you
-- are the moment you step through the door.
local function furnishUpperRooms(parent: Instance)
	local Y = 16

	-- ---- Art (-190, 103) ----
	for i = 0, 4 do
		local ex = -206 + i * 8
		part({ Name = "EaselLeg", Size = Vector3.new(0.4, 7, 0.4), CFrame = CFrame.new(ex, Y + 3.5, 96) * CFrame.Angles(math.rad(-10), 0, 0), Color = Color3.fromRGB(150, 116, 76), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
		part({ Name = "EaselCanvas", Size = Vector3.new(5, 5.4, 0.3), CFrame = CFrame.new(ex, Y + 6, 95.4) * CFrame.Angles(math.rad(-10), 0, 0), Color = Color3.fromRGB(248, 246, 238), Parent = parent }).CanCollide = false
		part({ Name = "EaselTray", Size = Vector3.new(5.4, 0.3, 1.2), CFrame = CFrame.new(ex, Y + 3.1, 95.8), Color = Color3.fromRGB(150, 116, 76), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
	end
	-- a colour wheel on the back wall
	for i = 0, 11 do
		local angle = i * math.pi / 6
		part({
			Name = "ColourChip",
			Size = Vector3.new(3.4, 3.4, 0.3),
			CFrame = CFrame.new(-190 + math.cos(angle) * 7, Y + 12 + math.sin(angle) * 7, 121.4) * CFrame.Angles(0, 0, angle),
			Color = Color3.fromHSV(i / 12, 0.72, 0.95),
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}).CanCollide = false
	end
	prop("Table", CFrame.new(-198, Y, 110))
	prop("Table", CFrame.new(-182, Y, 110))
	prop("Chair", CFrame.new(-198, Y, 114) * CFrame.Angles(0, math.pi, 0))
	prop("Chair", CFrame.new(-182, Y, 114) * CFrame.Angles(0, math.pi, 0))
	prop("Vase1", CFrame.new(-198, Y + 2.1, 110))
	prop("Bin", CFrame.new(-206, Y, 90))
	prop("SteelShelves2", CFrame.new(-212, Y, 100) * CFrame.Angles(0, math.rad(90), 0))

	-- ---- History (-122, 103) ----
	-- a timeline down the back wall, and cases under it
	for i = 0, 7 do
		local tx = -144 + i * 6.4
		part({ Name = "TimelineBar", Size = Vector3.new(6.4, 0.4, 0.3), CFrame = CFrame.new(tx, Y + 12, 121.4), Color = Color3.fromRGB(212, 178, 96), Parent = parent }).CanCollide = false
		part({ Name = "TimelinePin", Size = Vector3.new(3.4, 4.2, 0.3), CFrame = CFrame.new(tx, Y + (i % 2 == 0 and 15 or 9), 121.4), Color = Color3.fromRGB(228, 220, 196), Parent = parent }).CanCollide = false
	end
	for _, dx in { -136, -122, -108 } do
		part({ Name = "DisplayCase", Size = Vector3.new(8, 6, 4), CFrame = CFrame.new(dx, Y + 3, 116), Color = Color3.fromRGB(92, 62, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "DisplayGlass", Size = Vector3.new(7.4, 4.4, 3.6), CFrame = CFrame.new(dx, Y + 4, 116), Color = Color3.fromRGB(206, 232, 240), Material = Enum.Material.Glass, Transparency = 0.55, Parent = parent }).CanCollide = false
	end
	prop("GrandfatherClock", CFrame.new(-146, Y, 108) * CFrame.Angles(0, math.rad(90), 0))
	prop("Table", CFrame.new(-122, Y, 98))
	prop("Chair2", CFrame.new(-128, Y, 98) * CFrame.Angles(0, math.rad(90), 0))
	prop("Chair2", CFrame.new(-116, Y, 98) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Bookshelf", CFrame.new(-98, Y, 108) * CFrame.Angles(0, math.rad(-90), 0))

	-- ---- Computer Lab (122, 103) ----
	for row = 0, 1 do
		for col = 0, 4 do
			local mx = 106 + col * 8
			local mz = 96 + row * 12
			part({ Name = "LabDesk", Size = Vector3.new(7, 0.4, 4), CFrame = CFrame.new(mx, Y + 2.8, mz), Color = Color3.fromRGB(58, 62, 70), Material = Enum.Material.SmoothPlastic, Parent = parent })
			for _, lx in { -3, 3 } do
				part({ Name = "LabDeskLeg", Size = Vector3.new(0.3, 2.8, 3.4), CFrame = CFrame.new(mx + lx, Y + 1.4, mz), Color = Color3.fromRGB(80, 84, 92), Material = Enum.Material.Metal, Parent = parent })
			end
			part({ Name = "MonitorStand", Size = Vector3.new(0.5, 1.4, 0.5), CFrame = CFrame.new(mx, Y + 3.7, mz - 1), Color = Color3.fromRGB(40, 42, 48), Parent = parent }).CanCollide = false
			local screen = part({ Name = "Monitor", Size = Vector3.new(5, 3, 0.4), CFrame = CFrame.new(mx, Y + 5.9, mz - 1), Color = Color3.fromRGB(28, 30, 36), Parent = parent })
			screen.CanCollide = false
			part({ Name = "MonitorGlow", Size = Vector3.new(4.4, 2.4, 0.15), CFrame = CFrame.new(mx, Y + 5.9, mz - 1.25), Color = Color3.fromRGB(96, 172, 226), Material = Enum.Material.Neon, Parent = parent }).CanCollide = false
			part({ Name = "Keyboard", Size = Vector3.new(3.4, 0.2, 1.2), CFrame = CFrame.new(mx, Y + 3.1, mz + 0.8), Color = Color3.fromRGB(226, 224, 218), Parent = parent }).CanCollide = false
			prop("SchoolChair", CFrame.new(mx, Y, mz + 4) * CFrame.Angles(0, math.pi, 0))
		end
	end
	prop("OfficeDesk", CFrame.new(122, Y, 118))
	prop("Laptop", CFrame.new(122, Y + 2.9, 118))
	prop("Bin", CFrame.new(100, Y, 118))

	-- ---- Languages (190, 103) ----
	for i = 0, 5 do
		local bx = 172 + i * 7
		part({ Name = "LangBooth", Size = Vector3.new(6, 5, 5), CFrame = CFrame.new(bx, Y + 2.5, 112), Color = Color3.fromRGB(210, 214, 220), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "LangDesk", Size = Vector3.new(6, 0.4, 4), CFrame = CFrame.new(bx, Y + 2.8, 108), Color = Color3.fromRGB(178, 150, 112), Material = Enum.Material.WoodPlanks, Parent = parent })
		prop("SchoolChair", CFrame.new(bx, Y, 104) * CFrame.Angles(0, math.pi, 0))
	end
	for i, tint in {
		Color3.fromRGB(214, 72, 64), Color3.fromRGB(72, 128, 214), Color3.fromRGB(238, 190, 60),
		Color3.fromRGB(84, 178, 108), Color3.fromRGB(226, 226, 230), Color3.fromRGB(150, 100, 200),
	} do
		part({ Name = "LangFlag", Size = Vector3.new(6, 4, 0.3), CFrame = CFrame.new(172 + (i - 1) * 7, Y + 13, 121.4), Color = tint, Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
	end
	prop("OfficeDesk", CFrame.new(190, Y, 90))
	prop("Bin", CFrame.new(168, Y, 90))

	-- ---- Study Hall (-190, -94) ----
	for row = 0, 2 do
		local tz = -110 + row * 14
		prop("Table", CFrame.new(-198, Y, tz))
		prop("Table", CFrame.new(-182, Y, tz))
		for _, cx in { -198, -182 } do
			prop("Chair", CFrame.new(cx, Y, tz - 4))
			prop("Chair", CFrame.new(cx, Y, tz + 4) * CFrame.Angles(0, math.pi, 0))
		end
	end
	prop("SteelShelves", CFrame.new(-212, Y, -100) * CFrame.Angles(0, math.rad(90), 0))
	prop("Bookshelf", CFrame.new(-168, Y, -100) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Clock", CFrame.new(-190, Y + 11, -119.4))
	prop("Bin", CFrame.new(-212, Y, -74))

	-- ---- Drama (-122, -94) ----
	part({ Name = "DramaStage", Size = Vector3.new(34, 3, 16), CFrame = CFrame.new(-122, Y + 1.5, -110), Color = Color3.fromRGB(88, 62, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "DramaCurtain", Size = Vector3.new(7, 18, 1.2), CFrame = CFrame.new(-122 + side * 15, Y + 12, -102), Color = Color3.fromRGB(140, 26, 42), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
	end
	part({ Name = "DramaPelmet", Size = Vector3.new(36, 4, 1.2), CFrame = CFrame.new(-122, Y + 19, -102), Color = Color3.fromRGB(140, 26, 42), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
	for _, lx in { -10, 0, 10 } do
		local can = part({ Name = "Spotlight", Size = Vector3.new(2, 2, 3), CFrame = CFrame.new(-122 + lx, Y + 18, -94) * CFrame.Angles(math.rad(35), 0, 0), Color = Color3.fromRGB(34, 36, 42), Material = Enum.Material.Metal, Parent = parent })
		can.CanCollide = false
		local beam = Instance.new("SpotLight")
		beam.Angle = 50
		beam.Range = 40
		beam.Brightness = 2
		beam.Color = Color3.fromRGB(255, 236, 200)
		beam.Face = Enum.NormalId.Front
		beam.Parent = can
	end
	for i, tint in { Color3.fromRGB(240, 226, 190), Color3.fromRGB(60, 62, 70) } do
		part({ Name = "DramaMask", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 6, 2), CFrame = CFrame.new(-134 + (i - 1) * 24, Y + 13, -119.4), Color = tint, Parent = parent }).CanCollide = false
	end
	for i = 0, 5 do
		prop("MonoblocChair", CFrame.new(-134 + i * 5, Y, -80) * CFrame.Angles(0, math.rad(4 * i), 0))
	end

	-- ---- Nurse (122, -94) ----
	for i = 0, 2 do
		local bz = -112 + i * 12
		part({ Name = "WardBed", Size = Vector3.new(6, 2.4, 12), CFrame = CFrame.new(104, Y + 1.2, bz), Color = Color3.fromRGB(232, 236, 240), Material = Enum.Material.SmoothPlastic, Parent = parent })
		part({ Name = "WardMattress", Size = Vector3.new(5.4, 1, 11), CFrame = CFrame.new(104, Y + 2.7, bz), Color = Color3.fromRGB(206, 226, 232), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		part({ Name = "WardPillow", Size = Vector3.new(4.4, 0.9, 2.6), CFrame = CFrame.new(104, Y + 3.5, bz - 4), Color = Color3.fromRGB(248, 248, 246), Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		part({ Name = "WardScreen", Size = Vector3.new(0.4, 9, 11), CFrame = CFrame.new(109, Y + 4.5, bz), Color = Color3.fromRGB(180, 214, 210), Material = Enum.Material.Fabric, Parent = parent })
	end
	local cross = part({ Name = "NurseCross", Size = Vector3.new(8, 2.4, 0.4), CFrame = CFrame.new(122, Y + 13, -119.4), Color = Color3.fromRGB(226, 68, 68), Material = Enum.Material.Neon, Parent = parent })
	cross.CanCollide = false
	part({ Name = "NurseCross", Size = Vector3.new(2.4, 8, 0.4), CFrame = CFrame.new(122, Y + 13, -119.4), Color = Color3.fromRGB(226, 68, 68), Material = Enum.Material.Neon, Parent = parent }).CanCollide = false
	prop("OfficeDesk", CFrame.new(136, Y, -110))
	prop("SchoolChair", CFrame.new(136, Y, -104) * CFrame.Angles(0, math.pi, 0))
	prop("SteelShelves2", CFrame.new(144, Y, -96) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Bin", CFrame.new(144, Y, -74))
	prop("PottedPlant", CFrame.new(104, Y, -74))

	-- ---- Staff Room (190, -94) ----
	prop("Sofa", CFrame.new(176, Y, -110) * CFrame.Angles(0, math.rad(90), 0))
	prop("Sofa2", CFrame.new(190, Y, -116))
	prop("CoffeeTable", CFrame.new(183, Y, -110))
	prop("ArmChair", CFrame.new(190, Y, -104) * CFrame.Angles(0, math.pi, 0))
	prop("Table", CFrame.new(202, Y, -88))
	prop("Chair", CFrame.new(202, Y, -84) * CFrame.Angles(0, math.pi, 0))
	prop("VintageMicrowave", CFrame.new(210, Y + 3.4, -100) * CFrame.Angles(0, math.rad(-90), 0))
	prop("VintageElectricKettle", CFrame.new(210, Y + 3.4, -94) * CFrame.Angles(0, math.rad(-90), 0))
	part({ Name = "StaffCounter", Size = Vector3.new(5, 3.2, 22), CFrame = CFrame.new(211, Y + 1.6, -97), Color = Color3.fromRGB(150, 116, 82), Material = Enum.Material.WoodPlanks, Parent = parent })
	-- pigeonholes, which is the one thing a staff room always has
	for row = 0, 3 do
		for col = 0, 5 do
			part({
				Name = "Pigeonhole",
				Size = Vector3.new(0.6, 2.4, 3.4),
				CFrame = CFrame.new(165.2, Y + 4 + row * 2.6, -108 + col * 3.6),
				Color = row % 2 == col % 2 and Color3.fromRGB(206, 200, 188) or Color3.fromRGB(178, 170, 158),
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			}).CanCollide = false
		end
	end
	prop("Bin", CFrame.new(168, Y, -74))
	prop("Clock", CFrame.new(190, Y + 11, -119.4))
end


-- ================= THE TEACHERS' QUARTERS =================
-- Every professor in the timetable stands in a classroom all day and then
-- stands in it all night. They live here now: a lodge off the west path with
-- a common room downstairs and a study apiece above it, in the same brick as
-- the school so it reads as part of the campus rather than a prop dropped
-- next to it.
--
-- Students can walk in. That is the point -- a staff room you can be caught in
-- is worth more than one you cannot enter.
local TEACHERS = {
	{ name = "MR. TANGENT", subject = "Mathematics", color = Color3.fromRGB(120, 176, 255) },
	{ name = "DR. FIZZLE", subject = "Chemistry", color = Color3.fromRGB(150, 240, 190) },
	{ name = "MS. FERN", subject = "Biology", color = Color3.fromRGB(150, 220, 130) },
	{ name = "MAESTRO QUILL", subject = "Music", color = Color3.fromRGB(212, 160, 240) },
	{ name = "COACH BRICKER", subject = "Gym", color = Color3.fromRGB(255, 176, 88) },
}

local function buildTeachersQuarters(parent: Instance, center: Vector3)
	local W, D = 84, 64
	local halfW, halfD = W / 2, D / 2
	local GROUND, UPPER, RIDGE = 16, 32, 44
	local BRICK = Color3.fromRGB(138, 78, 62)
	local STONE = Color3.fromRGB(206, 200, 188)

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(center + Vector3.new(x, y, z))
	end

	-- ---- ground, plinth, floors ----
	tag(part({ Name = "QuartersPlinth", Size = Vector3.new(W + 8, 2, D + 8), CFrame = at(0, 1, 0), Color = STONE, Material = Enum.Material.Concrete, Parent = parent }), "TexBlueStone")
	tag(part({ Name = "QuartersFloor", Size = Vector3.new(W, 1, D), CFrame = at(0, 2.5, 0), Color = Color3.fromRGB(150, 110, 78), Material = Enum.Material.WoodPlanks, Parent = parent }), "TexWood")
	-- the upper deck, with a well over the common room so the fire is visible
	-- from the landing
	for _, rect in {
		{ -halfW, -halfD, halfW, -14 },
		{ -halfW, 14, halfW, halfD },
		{ -halfW, -14, -16, 14 },
		{ 16, -14, halfW, 14 },
	} do
		local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
		tag(part({ Name = "QuartersUpperFloor", Size = Vector3.new(x1 - x0, 1, z1 - z0), CFrame = at((x0 + x1) / 2, GROUND + 2.5, (z0 + z1) / 2), Color = Color3.fromRGB(150, 110, 78), Material = Enum.Material.WoodPlanks, Parent = parent }), "TexWood")
		tag(part({ Name = "QuartersSoffit", Size = Vector3.new(x1 - x0, 0.6, z1 - z0), CFrame = at((x0 + x1) / 2, GROUND + 1.7, (z0 + z1) / 2), Color = Color3.fromRGB(238, 234, 224), Parent = parent }), "TexCeiling")
	end
	-- railing round the well
	for _, rail in {
		{ -16, -14, 16, -14 }, { -16, 14, 16, 14 },
		{ -16, -14, -16, 14 }, { 16, -14, 16, 14 },
	} do
		buildRailing(parent, center + Vector3.new(rail[1], GROUND + 3, rail[2]), center + Vector3.new(rail[3], GROUND + 3, rail[4]))
	end

	-- ---- shell: brick with punched windows, doors on the campus side ----
	local function wall(name: string, size: Vector3, offset: Vector3)
		tag(part({ Name = name, Size = size, CFrame = at(offset.X, offset.Y, offset.Z), Color = BRICK, Material = Enum.Material.Brick, Parent = parent }), "TexBrick")
	end
	wall("QuartersWallN", Vector3.new(W, UPPER + 4, 2), Vector3.new(0, (UPPER + 4) / 2 + 3, -halfD))
	wall("QuartersWallW", Vector3.new(2, UPPER + 4, D), Vector3.new(-halfW, (UPPER + 4) / 2 + 3, 0))
	wall("QuartersWallS", Vector3.new(W, UPPER + 4, 2), Vector3.new(0, (UPPER + 4) / 2 + 3, halfD))
	-- east face: two piers and a lintel, the gap between them is the way in
	for _, sz in { -1, 1 } do
		wall("QuartersWallE", Vector3.new(2, UPPER + 4, halfD - 7), Vector3.new(halfW, (UPPER + 4) / 2 + 3, sz * (halfD / 2 + 3.5)))
	end
	wall("QuartersWallE", Vector3.new(2, UPPER + 4 - 14, 14), Vector3.new(halfW, (UPPER + 4) / 2 + 10, 0))
	for _, sz in { -7, 7 } do
		part({ Name = "QuartersDoorPost", Size = Vector3.new(3, 14, 2.4), CFrame = at(halfW, 10, sz), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })
	end

	-- windows: two rows of six on the long faces
	for _, sz in { -1, 1 } do
		for i = 0, 5 do
			for _, wy in { 11, 26 } do
				local wx = -32 + i * 13
				part({ Name = "QuartersWinFrame", Size = Vector3.new(8, 9, 2.6), CFrame = at(wx, wy, sz * halfD), Color = Color3.fromRGB(238, 236, 228), Material = Enum.Material.Concrete, Parent = parent })
				local glass = part({ Name = "QuartersWindow", Size = Vector3.new(6.2, 7, 2.9), CFrame = at(wx, wy, sz * halfD), Color = Color3.fromRGB(150, 200, 225), Material = Enum.Material.Glass, Transparency = 0.35, Parent = parent })
				glass.CanCollide = false
				tag(glass, "TexWindow")
			end
		end
	end

	-- ---- pitched roof ----
	for step = 0, 6 do
		local inset = step * 6
		part({
			Name = "QuartersRoof",
			Size = Vector3.new(W + 8 - inset, 2, D + 8 - inset),
			CFrame = at(0, UPPER + 5 + step * 1.9, 0),
			Color = Color3.fromRGB(96, 90, 84),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	local _ = RIDGE
	part({ Name = "QuartersChimney", Size = Vector3.new(9, 26, 9), CFrame = at(-halfW + 8, UPPER + 6, 0), Color = Color3.fromRGB(120, 68, 54), Material = Enum.Material.Brick, Parent = parent })

	-- ---- the sign over the door ----
	local sign = part({ Name = "QuartersSign", Size = Vector3.new(30, 5, 0.8), CFrame = at(halfW + 2.4, 18, 0), Color = Palette.Blackboard, Parent = parent })
	sign.CanCollide = false
	signText(sign, "TEACHERS' QUARTERS", Palette.BusYellow, Enum.NormalId.Right)
	signText(sign, "STAFF ONLY (GOOD LUCK)", Palette.BusYellow, Enum.NormalId.Left)

	-- ---- the common room ----
	-- a hearth on the west wall, which is the whole reason to come in
	part({ Name = "Hearth", Size = Vector3.new(4, 14, 20), CFrame = at(-halfW + 3, 10, 0), Color = Color3.fromRGB(150, 142, 130), Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "HearthOpening", Size = Vector3.new(2, 8, 12), CFrame = at(-halfW + 4.2, 7, 0), Color = Color3.fromRGB(28, 24, 22), Parent = parent }).CanCollide = false
	local fire = part({ Name = "HearthFire", Size = Vector3.new(1.6, 4, 9), CFrame = at(-halfW + 4.6, 5.4, 0), Color = Color3.fromRGB(255, 148, 52), Material = Enum.Material.Neon, Parent = parent })
	fire.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Brightness = 2.4
	glow.Range = 52
	glow.Color = Color3.fromRGB(255, 168, 96)
	glow.Parent = fire
	part({ Name = "HearthMantel", Size = Vector3.new(5.4, 1.2, 22), CFrame = at(-halfW + 3.4, 14.6, 0), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = parent })

	prop("ArmChair", CFrame.new(center + Vector3.new(-28, 3, -8)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("ArmChair", CFrame.new(center + Vector3.new(-28, 3, 8)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Sofa", CFrame.new(center + Vector3.new(-18, 3, 0)) * CFrame.Angles(0, math.rad(90), 0))
	prop("CoffeeTable", CFrame.new(center + Vector3.new(-23, 3, 0)))
	prop("Bookshelf", CFrame.new(center + Vector3.new(-34, 3, -22)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("Bookshelf", CFrame.new(center + Vector3.new(-34, 3, 22)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("GrandfatherClock", CFrame.new(center + Vector3.new(-6, 3, -29)))
	prop("PottedPlant", CFrame.new(center + Vector3.new(34, 3, -28)))
	prop("Fern", CFrame.new(center + Vector3.new(-12, 3, 26)))

	-- the long table they mark books at
	part({ Name = "StaffTable", Size = Vector3.new(26, 0.7, 7), CFrame = at(6, 6.4, -20), Color = Color3.fromRGB(122, 86, 56), Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, lx in { -11, 11 } do
		part({ Name = "StaffTableLeg", Size = Vector3.new(1.2, 3.6, 6), CFrame = at(6 + lx, 4.3, -20), Color = Color3.fromRGB(96, 66, 44), Material = Enum.Material.Wood, Parent = parent })
	end
	for i = 0, 3 do
		prop("Chair", CFrame.new(center + Vector3.new(-3 + i * 6, 3, -15)) * CFrame.Angles(0, math.pi, 0))
	end

	-- a kitchen counter along the north wall
	part({ Name = "StaffCounterTop", Size = Vector3.new(30, 0.6, 5), CFrame = at(18, 6.4, -halfD + 4), Color = Color3.fromRGB(216, 212, 202), Material = Enum.Material.Marble, Parent = parent })
	part({ Name = "StaffCounterBody", Size = Vector3.new(30, 3.4, 4.6), CFrame = at(18, 4.4, -halfD + 4), Color = Color3.fromRGB(96, 108, 122), Material = Enum.Material.SmoothPlastic, Parent = parent })
	part({ Name = "StaffSink", Size = Vector3.new(5, 0.4, 3.4), CFrame = at(10, 6.6, -halfD + 4), Color = Color3.fromRGB(184, 190, 196), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	prop("VintageElectricKettle", CFrame.new(center + Vector3.new(22, 6.8, -halfD + 4)))
	prop("VintageMicrowave", CFrame.new(center + Vector3.new(28, 6.8, -halfD + 4)))

	-- ---- the stair up, in the east bay ----
	buildStair(parent, CFrame.lookAt(center + Vector3.new(30, 3, 24), center + Vector3.new(30, 3, -4)), 14, 1, 1.9, 9)

	-- ---- five studies upstairs ----
	for index, teacher in TEACHERS do
		local sz = -halfD + 14 + (index - 1) * 11
		local doorX = 14
		-- a partition per study, opening onto the landing
		buildInteriorWall(
			parent,
			center + Vector3.new(-halfW + 2, GROUND + 3, sz),
			center + Vector3.new(doorX, GROUND + 3, sz),
			{}
		)
		local plaque = part({
			Name = "StudyPlaque",
			Size = Vector3.new(11, 2.6, 0.5),
			CFrame = at(doorX + 1.6, GROUND + 12, sz - 6),
			Color = Palette.Blackboard,
			Parent = parent,
		})
		plaque.CanCollide = false
		signText(plaque, teacher.name .. "\n" .. teacher.subject, teacher.color, Enum.NormalId.Right)

		-- a bed, a desk and a lamp: a study is a room somebody lives in
		part({ Name = "StudyBed", Size = Vector3.new(7, 2.6, 12), CFrame = at(-halfW + 8, GROUND + 4.3, sz - 6), Color = Color3.fromRGB(128, 92, 62), Material = Enum.Material.WoodPlanks, Parent = parent })
		part({ Name = "StudyMattress", Size = Vector3.new(6.4, 1.2, 11), CFrame = at(-halfW + 8, GROUND + 6.2, sz - 6), Color = teacher.color, Material = Enum.Material.Fabric, Parent = parent }).CanCollide = false
		prop("OfficeDesk", CFrame.new(center + Vector3.new(-halfW + 22, GROUND + 3, sz - 6)) * CFrame.Angles(0, math.rad(-90), 0))
		prop("SchoolChair", CFrame.new(center + Vector3.new(-halfW + 28, GROUND + 3, sz - 6)) * CFrame.Angles(0, math.rad(90), 0))
		prop("SteelShelves2", CFrame.new(center + Vector3.new(-halfW + 16, GROUND + 3, sz - 9)))
	end
	-- and a landing worth standing on
	prop("Sofa2", CFrame.new(center + Vector3.new(28, GROUND + 3, 22)) * CFrame.Angles(0, math.rad(-90), 0))
	prop("SideTable", CFrame.new(center + Vector3.new(22, GROUND + 3, 22)))
	prop("PottedPlant", CFrame.new(center + Vector3.new(30, GROUND + 3, -26)))
end


-- ================= THE SANCTUM =================
-- A door behind the bookshelf in the principal's office, a keypad, and a long
-- stair down to a pyramid nobody else on the server knows is there.
--
-- The shaft is a real hole: the school's base slab and the office floor are
-- both built around it (see FLOOR_HOLE) rather than the stair passing through
-- solid geometry, because a secret passage you can see the seams of is not
-- one. Access is checked on the server and the code is never sent to a client.
local SANCTUM_HOLE = { x0 = -222, z0 = 16, x1 = -206, z1 = 40 }
local SANCTUM_FLOOR = -80
local SANCTUM_CENTRE = Vector3.new(-214, SANCTUM_FLOOR, -34)

-- A floor slab with a rectangle missing, emitted as up to four parts.
local function floorWithHole(parent: Instance, name: string, centre: Vector3, size: Vector2, hole, texTag: string?)
	local x0, x1 = centre.X - size.X / 2, centre.X + size.X / 2
	local z0, z1 = centre.Z - size.Y / 2, centre.Z + size.Y / 2
	local hx0 = math.max(x0, hole.x0)
	local hx1 = math.min(x1, hole.x1)
	local hz0 = math.max(z0, hole.z0)
	local hz1 = math.min(z1, hole.z1)
	local rects
	if hx0 >= hx1 or hz0 >= hz1 then
		rects = { { x0, z0, x1, z1 } } -- the hole misses this slab entirely
	else
		rects = {
			{ x0, z0, hx0, z1 },
			{ hx1, z0, x1, z1 },
			{ hx0, z0, hx1, hz0 },
			{ hx0, hz1, hx1, z1 },
		}
	end
	for index, rect in rects do
		local rx0, rz0, rx1, rz1 = rect[1], rect[2], rect[3], rect[4]
		if rx1 - rx0 < 0.05 or rz1 - rz0 < 0.05 then
			continue
		end
		local piece = part({
			Name = name .. index,
			Size = Vector3.new(rx1 - rx0, 1, rz1 - rz0),
			CFrame = CFrame.new((rx0 + rx1) / 2, centre.Y, (rz0 + rz1) / 2),
			Color = Color3.fromRGB(196, 194, 188),
			Parent = parent,
		})
		if texTag then
			tag(piece, texTag)
		end
	end
end

local function buildSanctum(parent: Instance): BasePart
	local HOLE = SANCTUM_HOLE
	local shaftX = (HOLE.x0 + HOLE.x1) / 2

	-- ---- the bookshelf that is a door ----
	local shelf = part({
		Name = "SecretBookshelf",
		Size = Vector3.new(2.4, 15, 16),
		CFrame = CFrame.new(-222.6, 7.5, 28),
		Color = Color3.fromRGB(88, 58, 40),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for level = 0, 3 do
		part({ Name = "SecretShelfBoard", Size = Vector3.new(2.6, 0.5, 15.4), CFrame = CFrame.new(-222.6, 2 + level * 3.6, 28), Color = Color3.fromRGB(112, 76, 52), Material = Enum.Material.Wood, Parent = parent }).CanCollide = false
		for book = 0, 8 do
			part({
				Name = "SecretShelfBook",
				Size = Vector3.new(1.6, 2.6, 1.1),
				CFrame = CFrame.new(-221.9, 3.6 + level * 3.6, 21.4 + book * 1.55),
				Color = Color3.fromHSV(((level * 9 + book) % 12) / 12, 0.45, 0.62),
				Material = Enum.Material.Fabric,
				Parent = parent,
			}).CanCollide = false
		end
	end

	-- ---- the shaft head, hidden behind it ----
	part({ Name = "SanctumJamb", Size = Vector3.new(1.4, 16, 2), CFrame = CFrame.new(-220, 8, 14.6), Color = Color3.fromRGB(120, 114, 104), Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "SanctumJamb", Size = Vector3.new(1.4, 16, 2), CFrame = CFrame.new(-220, 8, 41.4), Color = Color3.fromRGB(120, 114, 104), Material = Enum.Material.Slate, Parent = parent })

	-- ---- the descent ----
	-- 52 treads at 1.54 by 1.54 drops eighty studs over eighty, which is a
	-- flight a Roblox character walks down without catching on a single step.
	local STEPS, RISE, RUN = 52, 1.54, 1.54
	for i = 0, STEPS - 1 do
		part({
			Name = "SanctumTread",
			Size = Vector3.new(14, 1.6, RUN + 0.4),
			CFrame = CFrame.new(shaftX, -RISE * i - 0.8, 36 - i * RUN),
			Color = Color3.fromRGB(150, 142, 128),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	-- shaft walls, so the flight is a passage and not a ledge over the void
	local shaftLength = STEPS * RUN + 8
	for _, side in { -1, 1 } do
		part({
			Name = "SanctumShaftWall",
			-- stops a stud below the floor: a shaft wall poking up through the
			-- office carpet is not much of a secret
			Size = Vector3.new(2, 92, shaftLength),
			CFrame = CFrame.new(shaftX + side * 8, -47, 38 - shaftLength / 2),
			Color = Color3.fromRGB(104, 98, 90),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	part({ Name = "SanctumShaftBack", Size = Vector3.new(18, 92, 2), CFrame = CFrame.new(shaftX, -47, 39), Color = Color3.fromRGB(104, 98, 90), Material = Enum.Material.Slate, Parent = parent })
	-- torches down the wall
	for i = 0, 5 do
		local tz = 30 - i * 13
		local ty = -RISE * ((30 - tz) / RUN) + 7
		local flame = part({ Name = "SanctumTorch", Size = Vector3.new(1.4, 2.4, 1.4), CFrame = CFrame.new(shaftX - 6.4, ty, tz), Color = Color3.fromRGB(255, 168, 76), Material = Enum.Material.Neon, Parent = parent })
		flame.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 34
		light.Color = Color3.fromRGB(255, 174, 96)
		light.Parent = flame
	end

	-- ---- the chamber ----
	local C = SANCTUM_CENTRE
	local ROOM, HEIGHT = 150, 64
	tag(part({ Name = "SanctumFloor", Size = Vector3.new(ROOM, 2, ROOM), CFrame = CFrame.new(C.X, C.Y - 1, C.Z), Color = Color3.fromRGB(58, 54, 50), Material = Enum.Material.Slate, Parent = parent }), "TexBlueStone")
	for _, wall in {
		{ Vector3.new(ROOM, HEIGHT, 2), Vector3.new(0, HEIGHT / 2, -ROOM / 2) },
		{ Vector3.new(ROOM, HEIGHT, 2), Vector3.new(0, HEIGHT / 2, ROOM / 2) },
		{ Vector3.new(2, HEIGHT, ROOM), Vector3.new(-ROOM / 2, HEIGHT / 2, 0) },
		{ Vector3.new(2, HEIGHT, ROOM), Vector3.new(ROOM / 2, HEIGHT / 2, 0) },
	} do
		tag(part({ Name = "SanctumWall", Size = wall[1], CFrame = CFrame.new(C + wall[2]), Color = Color3.fromRGB(74, 68, 62), Material = Enum.Material.Slate, Parent = parent }), "TexBrick")
	end
	-- ceiling, in four pieces around the shaft
	local top = C.Y + HEIGHT
	for _, rect in {
		{ C.X - ROOM / 2, C.Z - ROOM / 2, HOLE.x0, C.Z + ROOM / 2 },
		{ HOLE.x1, C.Z - ROOM / 2, C.X + ROOM / 2, C.Z + ROOM / 2 },
		{ HOLE.x0, C.Z - ROOM / 2, HOLE.x1, -6 },
		{ HOLE.x0, 42, HOLE.x1, C.Z + ROOM / 2 },
	} do
		local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
		if x1 - x0 < 0.5 or z1 - z0 < 0.5 then
			continue
		end
		part({ Name = "SanctumCeiling", Size = Vector3.new(x1 - x0, 2, z1 - z0), CFrame = CFrame.new((x0 + x1) / 2, top, (z0 + z1) / 2), Color = Color3.fromRGB(46, 42, 38), Material = Enum.Material.Slate, Parent = parent })
	end

	-- ---- the pyramid ----
	local BASE, LAYERS = 100, 22
	for i = 0, LAYERS - 1 do
		local span = BASE * (1 - i / LAYERS)
		tag(part({
			Name = "SanctumPyramid",
			Size = Vector3.new(span, 2.4, span),
			CFrame = CFrame.new(C.X, C.Y + 1.2 + i * 2.2, C.Z),
			Color = Color3.fromRGB(196, 176, 132),
			Material = Enum.Material.Sandstone,
			Parent = parent,
		}), "TexBlueStone")
	end
	local cap = part({
		Name = "SanctumCapstone",
		Size = Vector3.new(9, 7, 9),
		CFrame = CFrame.new(C.X, C.Y + 1.2 + LAYERS * 2.2 + 2, C.Z),
		Color = Color3.fromRGB(246, 206, 92),
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	local capGlow = Instance.new("PointLight")
	capGlow.Brightness = 3
	capGlow.Range = 90
	capGlow.Color = Color3.fromRGB(255, 214, 120)
	capGlow.Parent = cap

	-- braziers at the four corners, and a throne facing the stair
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local bx, bz = C.X + corner[1] * 62, C.Z + corner[2] * 62
		part({ Name = "SanctumBrazier", Size = Vector3.new(6, 8, 6), CFrame = CFrame.new(bx, C.Y + 4, bz), Color = Color3.fromRGB(92, 76, 52), Material = Enum.Material.Metal, Parent = parent })
		local fire = part({ Name = "SanctumBrazierFire", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(bx, C.Y + 9.5, bz), Color = Color3.fromRGB(255, 152, 60), Material = Enum.Material.Neon, Parent = parent })
		fire.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 2.6
		light.Range = 70
		light.Color = Color3.fromRGB(255, 164, 84)
		light.Parent = fire
	end
	part({ Name = "SanctumThrone", Size = Vector3.new(10, 4, 8), CFrame = CFrame.new(C.X, C.Y + 2, C.Z + 62), Color = Color3.fromRGB(88, 62, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
	part({ Name = "SanctumThroneBack", Size = Vector3.new(10, 16, 2), CFrame = CFrame.new(C.X, C.Y + 10, C.Z + 66), Color = Color3.fromRGB(88, 62, 44), Material = Enum.Material.WoodPlanks, Parent = parent })
	local crest = part({ Name = "SanctumCrest", Size = Vector3.new(7, 7, 0.6), CFrame = CFrame.new(C.X, C.Y + 14, C.Z + 64.8), Color = Color3.fromRGB(246, 206, 92), Material = Enum.Material.Neon, Parent = parent })
	crest.CanCollide = false

	return shelf
end

-- ================= FINDING YOUR WAY =================
-- A school you cannot navigate is a maze with lockers. Three things fix that,
-- and they are the three things real buildings use: a board at the door that
-- lists everything, a sign hanging over every room you might be looking for,
-- and a line on the floor you can follow without reading anything at all.
local ROUTES = {
	{ id = "math", label = "ROOM 101 · MATHS", icon = "➗", color = Color3.fromRGB(120, 176, 255),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(-74, 0, 65), Vector3.new(-74, 0, -60) } },
	{ id = "music", label = "MUSIC ROOM", icon = "🎵", color = Color3.fromRGB(212, 160, 240),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(74, 0, 65), Vector3.new(74, 0, -60) } },
	{ id = "biology", label = "GREENHOUSE · BIOLOGY", icon = "🧬", color = Color3.fromRGB(150, 220, 130),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(-116, 0, 65), Vector3.new(-116, 0, -8) } },
	{ id = "chemistry", label = "EAST LAB · CHEMISTRY", icon = "⚗️", color = Color3.fromRGB(150, 240, 190),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(116, 0, 65), Vector3.new(116, 0, -8) } },
	{ id = "gym", label = "GYM", icon = "🏀", color = Color3.fromRGB(255, 176, 88),
	  path = { Vector3.new(0, 0, 104), Vector3.new(0, 0, 65), Vector3.new(0, 0, -60) } },
}

-- Doors worth signposting from the hall, and what to call them.
local DOOR_SIGNS = {
	{ label = "ROOM 101 · MATHS", icon = "➗", at = Vector3.new(-74, 0, -62), face = 1, color = Color3.fromRGB(120, 176, 255) },
	{ label = "MUSIC ROOM", icon = "🎵", at = Vector3.new(74, 0, -62), face = 1, color = Color3.fromRGB(212, 160, 240) },
	{ label = "GYM", icon = "🏀", at = Vector3.new(0, 0, -62), face = 1, color = Color3.fromRGB(255, 176, 88) },
	{ label = "GREENHOUSE", icon = "🧬", at = Vector3.new(-116, 0, -9), face = 1, color = Color3.fromRGB(150, 220, 130) },
	{ label = "EAST LAB", icon = "⚗️", at = Vector3.new(116, 0, -9), face = 1, color = Color3.fromRGB(150, 240, 190) },
	{ label = "CAFETERIA", icon = "🍔", at = Vector3.new(-204, 0, 62), face = 1, color = Color3.fromRGB(235, 214, 156) },
	{ label = "OFFICE · THE STORE", icon = "🛒", at = Vector3.new(-204, 0, -50), face = -1, color = Color3.fromRGB(214, 226, 235) },
	{ label = "TROPHY HALL", icon = "🏆", at = Vector3.new(204, 0, -50), face = -1, color = Color3.fromRGB(240, 226, 190) },
	{ label = "DETENTION", icon = "⛓️", at = Vector3.new(204, 0, 62), face = 1, color = Color3.fromRGB(226, 96, 88) },
}

local function buildWayfinding(parent: Instance)
	-- ---- the coloured lines on the floor ----
	for index, route in ROUTES do
		-- every route leaves the lobby down the same hall, so they are fanned
		-- apart by a stud and a bit each. Without this they are one stripe,
		-- and a stripe that leads everywhere leads nowhere.
		local spread = (index - 3) * 1.2
		for i = 1, #route.path - 1 do
			local from, to = route.path[i], route.path[i + 1]
			local delta = to - from
			local length = delta.Magnitude
			if length < 1 then
				continue
			end
			-- shift across the run, whichever way it runs
			local sideways = if math.abs(delta.X) > math.abs(delta.Z)
				then Vector3.new(0, 0, spread)
				else Vector3.new(spread, 0, 0)
			local mid = from + delta * 0.5 + sideways + Vector3.new(0, 0.2, 0)
			local horizontal = Vector3.new(delta.X, 0, delta.Z).Unit
			local line = part({
				Name = "Route_" .. route.id,
				-- overlength by a stud so the corners meet instead of leaving
				-- a gap the eye has to jump
				Size = Vector3.new(0.9, 0.16, length + 1),
				CFrame = CFrame.lookAt(mid, mid + horizontal),
				Color = route.color,
				Material = Enum.Material.Neon,
				Parent = parent,
			})
			line.CanCollide = false
			line.CanQuery = false
		end
	end

	-- ---- a sign hanging in the hall over every door ----
	for _, door in DOOR_SIGNS do
		local sign = part({
			Name = "DoorSign",
			Size = Vector3.new(18, 4, 0.6),
			CFrame = CFrame.new(door.at + Vector3.new(0, 12.4, door.face * 2.5)),
			Color = Palette.Blackboard,
			Parent = parent,
		})
		sign.CanCollide = false
		signText(sign, door.icon .. " " .. door.label, door.color, Enum.NormalId.Front)
		signText(sign, door.icon .. " " .. door.label, door.color, Enum.NormalId.Back)
		local lamp = Instance.new("SurfaceLight")
		lamp.Face = if door.face > 0 then Enum.NormalId.Front else Enum.NormalId.Back
		lamp.Range = 20
		lamp.Brightness = 1.3
		lamp.Color = door.color
		lamp.Parent = sign
	end

	-- ---- the directory, where you come in ----
	local boardBack = part({ Name = "DirectoryBoard", Size = Vector3.new(20, 22, 1), CFrame = CFrame.new(-24, 12, 120.5), Color = Color3.fromRGB(58, 40, 30), Material = Enum.Material.WoodPlanks, Parent = parent })
	boardBack.CanCollide = false
	local face = part({ Name = "DirectoryFace", Size = Vector3.new(18, 20, 0.4), CFrame = CFrame.new(-24, 12, 119.9), Color = Palette.Blackboard, Parent = parent })
	face.CanCollide = false
	signText(face, "DIRECTORY\n\nGROUND\n101 MATHS · WEST\nMUSIC · EAST\nGREENHOUSE · WEST YARD\nEAST LAB · EAST YARD\nGYM · STRAIGHT ON\n\nUPSTAIRS\nART · HISTORY\nCOMPUTERS · LANGUAGES\nSTUDY · DRAMA\nNURSE · STAFF", Palette.Chalk, Enum.NormalId.Front)

	-- ---- overhead direction signs at the two junctions ----
	for _, spec in {
		{ at = Vector3.new(-74, 0, 66), text = "◀ 101 MATHS   GREENHOUSE ▶" },
		{ at = Vector3.new(74, 0, 66), text = "◀ EAST LAB   MUSIC ▶" },
		{ at = Vector3.new(0, 0, 66), text = "GYM ▼    UPSTAIRS ▲" },
	} do
		local hanger = part({ Name = "JunctionSign", Size = Vector3.new(26, 3.6, 0.5), CFrame = CFrame.new(spec.at + Vector3.new(0, 13.2, 0)), Color = Color3.fromRGB(30, 34, 44), Parent = parent })
		hanger.CanCollide = false
		signText(hanger, spec.text, Palette.BusYellow, Enum.NormalId.Front)
		signText(hanger, spec.text, Palette.BusYellow, Enum.NormalId.Back)
		part({ Name = "JunctionRod", Size = Vector3.new(0.3, 2.6, 0.3), CFrame = CFrame.new(spec.at + Vector3.new(-10, 16.2, 0)), Color = Color3.fromRGB(140, 144, 152), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
		part({ Name = "JunctionRod", Size = Vector3.new(0.3, 2.6, 0.3), CFrame = CFrame.new(spec.at + Vector3.new(10, 16.2, 0)), Color = Color3.fromRGB(140, 144, 152), Material = Enum.Material.Metal, Parent = parent }).CanCollide = false
	end
end

function MapService.Build(): Map
-- Every part the school builds defaults to queryable, touchable and
-- shadow-casting. On a campus this size that is thousands of parts taxing
-- every raycast, every Touched event and every light update — which is a large
-- part of why moving around felt heavy.
--
-- A part that is anchored, non-collidable and carries no interaction is
-- decoration by definition: nothing should ever raycast it, touch it, or ask
-- it for a shadow. Structure (anything you can walk into) keeps every flag, so
-- the aim reticle still stops at walls.
local function optimize(root: Instance)
	for _, part in root:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part:IsA("MeshPart") then
			-- precise mesh collision on scenery is the most expensive default
			-- in the engine and buys us nothing
			part.CollisionFidelity = Enum.CollisionFidelity.Box
		end
		-- Signage is never something you walk into. Generated geometry makes it
		-- very easy to plant a board or a post exactly where a door goes, and
		-- the only reliable defence is that none of it is ever solid.
		local n = part.Name
		if n:find("Sign") or n:find("Plaque") or n:find("Board") or n:find("Banner")
			or n:find("Crest") or n:find("Emblem") or n:find("Pennant") or n:find("Motto")
		then
			part.CanCollide = false
		end
		if not part.Anchored or part.CanCollide then
			continue
		end
		local interactive = part:FindFirstChildWhichIsA("ProximityPrompt")
			or part:FindFirstChildWhichIsA("ClickDetector")
			or part:FindFirstChildWhichIsA("SurfaceGui")
			or part:FindFirstChildWhichIsA("BillboardGui")
		if interactive then
			continue
		end
		part.CanQuery = false
		part.CanTouch = false
		if part.Size.Magnitude < 12 then
			part.CastShadow = false
		end
	end
end

	trimRuns = {}
	propRequests = {}

	local folder = Instance.new("Folder")
	folder.Name = "CrumbworthHigh"

	buildTerrain()

	-- ================= THE FLOOR PLAN =================
	-- Followed from the CAD plan: a symmetric school. Central spine =
	-- entrance lobby (south) -> atrium -> big gym hall (north, protruding).
	-- Each wing = ring corridor around an open inner courtyard, rooms on the
	-- perimeter. Main corridor (the conveyor) runs the full width at z=70.
	--
	--   x: -224 .. 224      z: -124 (north) .. 124 (south), gym to -146
	--   S rooms row  z[76,124]   : plots A/B + janitor | LOBBY | mirrored
	--   Main corridor z[64,76]   : full width, lockers, conveyor line
	--   Middle band  z[-64,64]   : outer col rooms | inner corridor |
	--                              courtyard | spine atrium | mirrored
	--   N corridor   z[-64,-52]  : per wing
	--   N rooms row  z[-124,-64] : plots C/D + classroom | gym flanks
	-- ===================================================

	-- interior base slab
	-- built around the sanctum shaft rather than over it
	floorWithHole(folder, "SchoolBaseFloor", Vector3.new(0, -0.55, 0), Vector2.new(448, 248), SANCTUM_HOLE, "TexFloorTile")

	-- main corridor floor + stripe (the conveyor line)
	tag(part({
		Name = "HallwayFloor",
		Size = Vector3.new(448, 1, 32),
		CFrame = CFrame.new(0, -0.5, 65),
		Color = Color3.fromRGB(196, 194, 188),
		Parent = folder,
	}), "TexFloorTile")
	part({
		Name = "HallwayStripe",
		Size = Vector3.new(440, 0.2, 2.4),
		CFrame = CFrame.new(0, 0.11, 65),
		Color = Palette.BusYellow,
		Material = Enum.Material.Neon,
		Parent = folder,
	})

	-- ---------------- plots: 8 homerooms on the perimeter rows ----------------
	local plots: { Plot } = {}
	-- south row (doors north onto the main corridor)
	for i, x in { -190, -122 } do
		local c = Vector3.new(x, 0, 103)
		table.insert(plots, buildPlot(i, CFrame.lookAt(c, c + Vector3.new(0, 0, -1)), folder))
	end
	for i, x in { 122, 190 } do
		local c = Vector3.new(x, 0, 103)
		table.insert(plots, buildPlot(2 + i, CFrame.lookAt(c, c + Vector3.new(0, 0, -1)), folder))
	end
	-- north row (doors south onto the wing corridor)
	for i, x in { -190, -122 } do
		local c = Vector3.new(x, 0, -94)
		table.insert(plots, buildPlot(4 + i, CFrame.lookAt(c, c + Vector3.new(0, 0, 1)), folder))
	end
	for i, x in { 122, 190 } do
		local c = Vector3.new(x, 0, -94)
		table.insert(plots, buildPlot(6 + i, CFrame.lookAt(c, c + Vector3.new(0, 0, 1)), folder))
	end

	-- ---------------- room floors (plan rooms, both wings) ----------------
	buildZone(folder, "Cafeteria", Vector3.new(-204, 0, -23), Vector2.new(40, 58), Color3.fromRGB(235, 214, 156), "CAFETERIA", Enum.Material.CeramicTiles)
	buildZone(folder, "PrincipalsOffice", Vector3.new(-204, 0, 35), Vector2.new(40, 58), Color3.fromRGB(214, 226, 235), "PRINCIPAL'S OFFICE\n(THE STORE)", Enum.Material.Marble)
	-- and cut the same shaft out of the office floor the zone just laid down
	for _, existing in folder:GetChildren() do
		if existing.Name == "PrincipalsOfficeFloor" then
			existing:Destroy()
		end
	end
	floorWithHole(folder, "PrincipalsOfficeFloor", Vector3.new(-204, -0.5, 35), Vector2.new(40, 58), SANCTUM_HOLE, "TexFloorTile")
	local trophyFloor = buildZone(folder, "TrophyHall", Vector3.new(204, 0, -23), Vector2.new(40, 58), Color3.fromRGB(228, 228, 228), "TROPHY HALL", Enum.Material.Marble)
	buildZone(folder, "Detention", Vector3.new(204, 0, 35), Vector2.new(40, 58), Color3.fromRGB(126, 126, 132), "DETENTION", Enum.Material.Concrete)
	tag(buildZone(folder, "Classroom101", Vector3.new(-74, 0, -94), Vector2.new(28, 60), Color3.fromRGB(148, 118, 96), "ROOM 101\nMATHEMATICS", Enum.Material.Carpet), "TexCarpet")
	buildZone(folder, "MusicRoom", Vector3.new(74, 0, -94), Vector2.new(28, 60), Color3.fromRGB(196, 168, 210), "MUSIC ROOM", Enum.Material.Carpet)
	-- the two science annexes, dropped into the courtyards
	buildPavilion(
		folder,
		"Greenhouse",
		Vector3.new(-116, 0, -28),
		Vector2.new(36, 34),
		"THE GREENHOUSE\nBIOLOGY",
		Color3.fromRGB(150, 220, 130),
		Color3.fromRGB(206, 238, 210)
	)
	buildPavilion(
		folder,
		"EastLab",
		Vector3.new(116, 0, -28),
		Vector2.new(36, 34),
		"EAST LAB\nCHEMISTRY",
		Color3.fromRGB(150, 240, 190),
		Color3.fromRGB(202, 232, 240)
	)
	buildZone(folder, "Gym", Vector3.new(0, 0, -105), Vector2.new(100, 82), Color3.fromRGB(210, 160, 110), "GYM — FIGHT ZONE", Enum.Material.WoodPlanks)
	buildCheckerFloor(folder, Vector3.new(0, 0, 0), Vector2.new(120, 128)) -- atrium
	-- courtyards: open-air grass
	for _, cx in { -116, 116 } do
		local lawn = part({
			Name = "CourtyardLawn",
			Size = Vector3.new(112, 1, 104),
			CFrame = CFrame.new(cx, -0.45, 0),
			Color = Color3.fromRGB(112, 168, 82),
			Material = Enum.Material.Grass,
			Parent = folder,
		})
		tag(lawn, "TexGround")
	end

	-- ---------------- walls: exterior (two-story look) ----------------
	local T = true
	-- south face: wings + lobby with grand doors
	buildFacadeWall(folder, Vector3.new(-224, 0, 124), Vector3.new(-60, 0, 124), {})
	buildFacadeWall(folder, Vector3.new(60, 0, 124), Vector3.new(224, 0, 124), {})
	buildFacadeWall(folder, Vector3.new(-60, 0, 124), Vector3.new(60, 0, 124), { { at = 60, width = 26 } })
	-- north face (interrupted by the gym block)
	buildFacadeWall(folder, Vector3.new(-224, 0, -124), Vector3.new(-60, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(60, 0, -124), Vector3.new(224, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(-60, 0, -124), Vector3.new(-50, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(50, 0, -124), Vector3.new(60, 0, -124), {})
	-- gym protrusion
	buildFacadeWall(folder, Vector3.new(-50, 0, -124), Vector3.new(-50, 0, -146), {})
	buildFacadeWall(folder, Vector3.new(50, 0, -146), Vector3.new(50, 0, -124), {})
	buildFacadeWall(folder, Vector3.new(-50, 0, -146), Vector3.new(50, 0, -146), {})
	-- east/west faces
	buildFacadeWall(folder, Vector3.new(-224, 0, -124), Vector3.new(-224, 0, 124), {})
	buildFacadeWall(folder, Vector3.new(224, 0, 124), Vector3.new(224, 0, -124), {})

	-- ---------------- walls: interior ----------------
	local function mirrorX(v: Vector3): Vector3
		return Vector3.new(-v.X, v.Y, v.Z)
	end
	local function wingWalls(sgn: number)
		local function W(a: Vector3, b: Vector3, gaps)
			if sgn < 0 then
				buildInteriorWall(folder, a, b, gaps or {})
			else
				buildInteriorWall(folder, mirrorX(a), mirrorX(b), gaps or {})
			end
		end
		-- z=76: plot bays OPEN onto the corridor (their laser gates are the
		-- front wall); only stubs at bay edges + the janitor room front
		W(Vector3.new(-224, 0, 81), Vector3.new(-218, 0, 81), {})
		W(Vector3.new(-162, 0, 81), Vector3.new(-150, 0, 81), {})
		W(Vector3.new(-94, 0, 81), Vector3.new(-88, 0, 81), {})
		W(Vector3.new(-88, 0, 81), Vector3.new(-60, 0, 81), { { at = 14, width = 8 } })
		-- z=49: courtyard south colonnade. It used to stand at z=59, which left
		-- the main hallway 22 studs across -- narrow enough that two students
		-- and a professor filled it. Ten studs off the courtyard's south end
		-- buys a hall you can actually move through.
		W(Vector3.new(-172, 0, 49), Vector3.new(-60, 0, 49), { { at = 32, width = 18 }, { at = 80, width = 18 } })
		-- z=-52: cafeteria front (door) + courtyard north wall (arch)
		W(Vector3.new(-224, 0, -52), Vector3.new(-184, 0, -52), { { at = 20, width = 12 } })
		W(Vector3.new(-172, 0, -52), Vector3.new(-60, 0, -52), { { at = 56, width = 16 } })
		-- z=-64: north plot bays OPEN onto the full-width wing corridor;
		-- stubs at bay edges + the classroom front with its door
		W(Vector3.new(-224, 0, -64), Vector3.new(-218, 0, -64), {})
		W(Vector3.new(-162, 0, -64), Vector3.new(-150, 0, -64), {})
		W(Vector3.new(-94, 0, -64), Vector3.new(-88, 0, -64), {})
		W(Vector3.new(-88, 0, -64), Vector3.new(-60, 0, -64), { { at = 14, width = 10 } })
		-- x=-184: outer column onto inner corridor (cafeteria + principal doors)
		W(Vector3.new(-184, 0, -52), Vector3.new(-184, 0, 49), { { at = 29, width = 12 }, { at = 87, width = 12 } })
		-- x=-172: inner corridor onto courtyard (two arches)
		W(Vector3.new(-172, 0, -52), Vector3.new(-172, 0, 49), { { at = 28, width = 14 }, { at = 76, width = 14 } })
		-- room separators, south row then north row
		W(Vector3.new(-156, 0, 81), Vector3.new(-156, 0, 124), {})
		W(Vector3.new(-88, 0, 81), Vector3.new(-88, 0, 124), {})
		W(Vector3.new(-156, 0, -124), Vector3.new(-156, 0, -64), {})
		W(Vector3.new(-88, 0, -124), Vector3.new(-88, 0, -64), {})
		-- cafeteria/principal divider (outer column now starts at z=-52)
		W(Vector3.new(-224, 0, 6), Vector3.new(-184, 0, 6), {})
	end
	wingWalls(-1)
	wingWalls(1)

	-- spine walls
	buildInteriorWall(folder, Vector3.new(-60, 0, 81), Vector3.new(-60, 0, 124), {})
	buildInteriorWall(folder, Vector3.new(-26, 0, 81), Vector3.new(26, 0, 81), { { at = 26, width = 22 } }) -- lobby west
	buildInteriorWall(folder, Vector3.new(60, 0, 81), Vector3.new(60, 0, 124), {}) -- lobby east
	buildInteriorWall(folder, Vector3.new(-60, 0, -64), Vector3.new(-60, 0, 64), { { at = 70, width = 12 } }) -- atrium west (arch to courtyard)
	buildInteriorWall(folder, Vector3.new(60, 0, -64), Vector3.new(60, 0, 64), { { at = 70, width = 12 } }) -- atrium east
	buildInteriorWall(folder, Vector3.new(-50, 0, -64), Vector3.new(50, 0, -64), { { at = 50, width = 20 } }) -- gym south (grand doors)
	buildInteriorWall(folder, Vector3.new(-60, 0, -64), Vector3.new(-60, 0, -124), {}) -- west flank outer
	buildInteriorWall(folder, Vector3.new(60, 0, -124), Vector3.new(60, 0, -64), {}) -- east flank outer
	buildInteriorWall(folder, Vector3.new(-50, 0, -64), Vector3.new(-50, 0, -124), {}) -- gym west (flank divider)
	buildInteriorWall(folder, Vector3.new(50, 0, -124), Vector3.new(50, 0, -64), {}) -- gym east

	-- open doors on the main rooms
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(-204, 0, 64), Vector3.new(-204, 0, 60)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(204, 0, 64), Vector3.new(204, 0, 60)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(-204, 0, -52), Vector3.new(-204, 0, -48)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(204, 0, -52), Vector3.new(204, 0, -48)), 12, true)
	addOpenDoor(folder, CFrame.lookAt(Vector3.new(0, 0, -64), Vector3.new(0, 0, -68)), 18, true)

	-- ---------------- lockers on real wall sections ----------------
	for _, spec in {
		{ cf = CFrame.new(-58.6, 4.2, 20), rot = 90 }, -- atrium west wall
		{ cf = CFrame.new(58.6, 4.2, 20), rot = 90 }, -- atrium east wall
		{ cf = CFrame.new(-58.6, 4.2, -30), rot = 90 },
		{ cf = CFrame.new(58.6, 4.2, -30), rot = 90 },
	} do
		tag(part({
			Name = "LockerBank",
			Size = Vector3.new(24, 8.4, 1.6),
			CFrame = spec.cf * CFrame.Angles(0, math.rad(spec.rot), 0),
			Color = Color3.fromRGB(46, 84, 168),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		}), "TexLocker")
	end
	-- columns along the open corridor edges (colonnade + lobby + atrium)
	for _, colSpec in {
		{ z = 59, xs = { -160, -132, -104, -76 } },
		{ z = 59, xs = { 76, 104, 132, 160 } },
		-- no column at x = 0: that is the middle of the lobby opening
		{ z = 81, xs = { -40, 40 } },
	} do
		for _, cx in colSpec.xs do
			part({
				Name = "CorridorColumn",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(15.4, 1.5, 1.5),
				CFrame = CFrame.new(cx, 7.7, colSpec.z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(238, 234, 224),
				Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			})
		end
	end
	for _, xEnd in { -218, 218 } do
		local sign = part({
			Name = "HallwaySign",
			Size = Vector3.new(2, 5, 10),
			CFrame = CFrame.new(xEnd, 7, 70),
			Color = Palette.Blackboard,
			Parent = folder,
		})
		signText(sign, "MAIN HALLWAY", Palette.BusYellow, Enum.NormalId.Left)
		signText(sign, "MAIN HALLWAY", Palette.BusYellow, Enum.NormalId.Right)
	end
	-- corridor ceiling lights
	for i = 0, 26 do
		part({ Name = "CeilingDot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), CFrame = CFrame.new(-208 + i * 16, 14.4, 70) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 248, 230), Material = Enum.Material.Neon, Parent = folder })
	end

	-- ---------------- roofs (flat slabs; courtyards stay open) ----------------
	local function roofSlab(cx: number, cz: number, sx: number, sz: number, y: number?)
		tag(part({
			Name = "RoofSlab",
			Size = Vector3.new(sx, 1.2, sz),
			CFrame = CFrame.new(cx, y or 16.2, cz),
			Color = Color3.fromRGB(228, 226, 220),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		}), "TexCeiling")
	end
	roofSlab(0, 102, 448, 44) -- south rooms + lobby (pitched roof sits above)
	roofSlab(0, 70, 448, 22) -- corridor
	roofSlab(-116, 58, 112, 12) -- west colonnade
	roofSlab(116, 58, 112, 12) -- east colonnade
	roofSlab(-116, -58, 112, 12) -- west north leg
	roofSlab(116, -58, 112, 12) -- east north leg
	roofSlab(0, 0, 120, 128) -- atrium (with skylight ring)
	roofSlab(-142, 102, 168, 46) -- west south rooms
	roofSlab(142, 102, 168, 46) -- east south rooms
	roofSlab(-142, -94, 168, 62) -- west north rooms
	roofSlab(142, -94, 168, 62) -- east north rooms
	roofSlab(-198, 0, 54, 130) -- west outer column
	roofSlab(198, 0, 54, 130) -- east outer column
	roofSlab(0, -105, 106, 88, 26.2) -- gym: double height
	roofSlab(-55, -94, 10, 60) -- west flank
	roofSlab(55, -94, 10, 60) -- east flank
	-- atrium skylight
	part({
		Name = "Skylight",
		Size = Vector3.new(44, 0.6, 44),
		CFrame = CFrame.new(0, 16.4, 6),
		Color = Color3.fromRGB(170, 215, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		Parent = folder,
	})

	-- ---------------- signature interiors ----------------
	buildFountain(folder, Vector3.new(0, 0, 6)) -- atrium centerpiece
	buildCafeteriaTables(folder, Vector3.new(-204, 0, -23))
	buildGymMarkings(folder, Vector3.new(0, 0, -105))
	buildHoops(folder, Vector3.new(0, 0, -105))
	-- gym stage at the north end
	part({ Name = "GymStage", Size = Vector3.new(60, 3, 16), CFrame = CFrame.new(0, 1.5, -136), Color = Color3.fromRGB(120, 70, 50), Material = Enum.Material.WoodPlanks, Parent = folder })
	-- Classroom 101 is the box x -88..-60, z -124..-64. The grid has been wrong
	-- twice: it ran to z = -86 (through the partition at z = -94) and then to
	-- x = -96 (through the west wall at x = -88, into the homeroom next door).
	-- Two columns of three, facing the professor, wholly inside the room.
	for row = 0, 2 do
		for col = 0, 1 do
			local dx, dz = -80 + col * 12, -100 + row * 10
			-- a top on legs with a chair behind it, rather than a solid block:
			-- furniture you can see under is most of what makes a room read
			local unit = Instance.new("Folder")
			unit.Name = "ClassDeskUnit"
			unit.Parent = folder
			part({ Name = "ClassDeskTop", Size = Vector3.new(6, 0.4, 3), CFrame = CFrame.new(dx, 2.6, dz), Color = Color3.fromRGB(196, 158, 118), Material = Enum.Material.WoodPlanks, Parent = unit })
			for _, lx in { -2.5, 2.5 } do
				for _, lz in { -1.2, 1.2 } do
					part({ Name = "ClassDeskLeg", Size = Vector3.new(0.35, 2.4, 0.35), CFrame = CFrame.new(dx + lx, 1.2, dz + lz), Color = Color3.fromRGB(104, 108, 116), Material = Enum.Material.Metal, Parent = unit })
				end
			end
			local seat = Instance.new("Folder")
			seat.Name = "ClassChairUnit"
			seat.Parent = folder
			part({ Name = "ClassChairSeat", Size = Vector3.new(2.6, 0.35, 2.4), CFrame = CFrame.new(dx, 1.7, dz + 3.4), Color = Color3.fromRGB(86, 116, 158), Material = Enum.Material.SmoothPlastic, Parent = seat })
			part({ Name = "ClassChairBack", Size = Vector3.new(2.6, 2.2, 0.35), CFrame = CFrame.new(dx, 2.8, dz + 4.4), Color = Color3.fromRGB(86, 116, 158), Material = Enum.Material.SmoothPlastic, Parent = seat })
			for _, lx in { -1, 1 } do
				part({ Name = "ClassChairLeg", Size = Vector3.new(0.3, 1.5, 0.3), CFrame = CFrame.new(dx + lx, 0.75, dz + 3.4), Color = Color3.fromRGB(104, 108, 116), Material = Enum.Material.Metal, Parent = seat })
			end
			-- the board is to the north, so both face -Z
			prop("SchoolDesk", CFrame.new(dx, 0, dz) * CFrame.Angles(0, math.pi, 0), { fallback = unit })
			prop("SchoolChair", CFrame.new(dx, 0, dz + 3.6) * CFrame.Angles(0, math.pi, 0), { fallback = seat })
		end
	end
	-- against the far wall, facing the desks. It used to sit at z = -67, which
	-- is the doorway, so the room could not be walked into.
	local classBoard = part({ Name = "ClassBoard", Size = Vector3.new(18, 8, 0.6), CFrame = CFrame.new(-74, 6, -121), Color = Palette.Blackboard, Parent = folder })
	classBoard.CanCollide = false
	signText(classBoard, "CLASSROOM 101", Palette.White, Enum.NormalId.Front)

	-- trophy hall boards
	local trophyCashBoard = part({
		Name = "TrophyCashBoard",
		Size = Vector3.new(1, 12, 22),
		CFrame = CFrame.new(221.5, 7, -42),
		Color = Palette.Blackboard,
		Parent = folder,
	})
	local trophyAuraBoard = part({
		Name = "TrophyAuraBoard",
		Size = Vector3.new(1, 12, 22),
		CFrame = CFrame.new(221.5, 7, -14),
		Color = Palette.Blackboard,
		Parent = folder,
	})

	-- clique boards along the west courtyard's north wall
	local Cliques = require(ReplicatedStorage.Config.Cliques)
	local cliqueBoards: { [string]: BasePart } = {}
	for i, clique in Cliques.List do
		local board = part({
			Name = "CliqueBoard_" .. clique.id,
			Size = Vector3.new(13, 8, 1),
			CFrame = CFrame.new(-166 + (i - 1) * 30, 4.5, -47),
			Color = clique.color,
			Parent = folder,
		})
		signText(board, clique.name:upper() .. "\n" .. clique.motto, Palette.White, Enum.NormalId.Front)
		signText(board, clique.name:upper(), Palette.White, Enum.NormalId.Back)
		cliqueBoards[clique.id] = board
	end

	-- west courtyard dressing: flowerbeds + trees; east courtyard: courts
	buildFlowerbed(folder, Vector3.new(-150, 0, 20))
	buildFlowerbed(folder, Vector3.new(-86, 0, 20))
	buildTree(folder, Vector3.new(-146, 0, -16), 1.1)
	buildTree(folder, Vector3.new(-90, 0, 24), 0.95)
	local courtBase = part({ Name = "BasketballCourt", Size = Vector3.new(34, 0.2, 22), CFrame = CFrame.new(96, 0.11, -14), Color = Color3.fromRGB(52, 118, 190), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local _cb = courtBase
	part({ Name = "CourtKey", Size = Vector3.new(10, 0.22, 22), CFrame = CFrame.new(96, 0.12, -14), Color = Color3.fromRGB(226, 130, 62), Material = Enum.Material.SmoothPlastic, Parent = folder })
	for _, hoopX in { 80, 112 } do
		part({ Name = "HoopPost", Size = Vector3.new(0.8, 11, 0.8), CFrame = CFrame.new(hoopX, 5.5, -14), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Parent = folder })
	end
	local volleyBase = part({ Name = "VolleyballCourt", Size = Vector3.new(30, 0.2, 18), CFrame = CFrame.new(120, 0.11, 24), Color = Color3.fromRGB(226, 148, 168), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local _vb = volleyBase
	part({ Name = "VolleyNet", Size = Vector3.new(0.2, 2.4, 17), CFrame = CFrame.new(120, 6.4, 24), Color = Color3.fromRGB(235, 235, 235), Material = Enum.Material.Fabric, Transparency = 0.35, Parent = folder })

	-- ---- lobby dressing ----
	-- It was a grey box with a doorway in it, and it is the second thing
	-- anyone sees. A school entrance hall is a reception desk, a trophy run,
	-- somewhere to sit and something to read.
	part({ Name = "LobbyDesk", Size = Vector3.new(18, 3.4, 4), CFrame = CFrame.new(-30, 1.7, 92), Color = Color3.fromRGB(120, 84, 58), Material = Enum.Material.WoodPlanks, Parent = folder })
	part({ Name = "LobbyDeskTop", Size = Vector3.new(19.4, 0.4, 5), CFrame = CFrame.new(-30, 3.6, 92), Color = Color3.fromRGB(196, 158, 118), Material = Enum.Material.WoodPlanks, Parent = folder })
	part({ Name = "LobbyDeskBack", Size = Vector3.new(18, 8, 0.8), CFrame = CFrame.new(-30, 4, 96), Color = Color3.fromRGB(150, 112, 82), Material = Enum.Material.WoodPlanks, Parent = folder })

	-- trophy cases down the east wall
	for i = 0, 2 do
		local cz = 86 + i * 13
		part({ Name = "LobbyCaseFrame", Size = Vector3.new(1.6, 11, 11), CFrame = CFrame.new(46, 5.5, cz), Color = Color3.fromRGB(96, 68, 48), Material = Enum.Material.WoodPlanks, Parent = folder })
		part({ Name = "LobbyCaseGlass", Size = Vector3.new(0.5, 9, 9.4), CFrame = CFrame.new(45.1, 5.6, cz), Color = Color3.fromRGB(186, 214, 226), Material = Enum.Material.Glass, Transparency = 0.55, Parent = folder })
		for j = 0, 1 do
			part({ Name = "LobbyTrophy", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.5, 1.5), CFrame = CFrame.new(45.6, 3 + j * 4, cz - 2.6 + j * 5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(226, 186, 92), Material = Enum.Material.Metal, Parent = folder })
		end
	end

	-- benches facing the desk, with a runner between them
	for _, bz in { 88, 102 } do
		part({ Name = "LobbyBenchSeat", Size = Vector3.new(3.4, 0.5, 16), CFrame = CFrame.new(18, 2.4, bz), Color = Color3.fromRGB(158, 116, 82), Material = Enum.Material.WoodPlanks, Parent = folder })
		for _, lz in { -6.5, 6.5 } do
			part({ Name = "LobbyBenchLeg", Size = Vector3.new(2.8, 2.2, 0.6), CFrame = CFrame.new(18, 1.2, bz + lz), Color = Color3.fromRGB(104, 108, 116), Material = Enum.Material.Metal, Parent = folder })
		end
	end
	tag(part({ Name = "LobbyRunner", Size = Vector3.new(20, 0.16, 40), CFrame = CFrame.new(0, 0.2, 100), Color = Color3.fromRGB(132, 68, 60), Material = Enum.Material.Fabric, Parent = folder }), "TexCarpet")

	-- notice board by the doors, and planters flanking the way in
	local notice = part({ Name = "LobbyNotice", Size = Vector3.new(0.5, 9, 16), CFrame = CFrame.new(-52, 7, 104), Color = Palette.Blackboard, Parent = folder })
	signText(notice, "NOTICES\nBELL 8:40\nDETENTION 4PM", Palette.Chalk, Enum.NormalId.Right)
	for _, side in { -1, 1 } do
		part({ Name = "LobbyPlanter", Size = Vector3.new(6, 3.4, 6), CFrame = CFrame.new(side * 30, 1.7, 116), Color = Color3.fromRGB(150, 118, 96), Material = Enum.Material.Concrete, Parent = folder })
		part({ Name = "LobbyPlanterSoil", Size = Vector3.new(5, 0.4, 5), CFrame = CFrame.new(side * 30, 3.5, 116), Color = Color3.fromRGB(78, 62, 48), Material = Enum.Material.Ground, Parent = folder })
		part({ Name = "TreeTrunk", Size = Vector3.new(1.2, 7, 1.2), CFrame = CFrame.new(side * 30, 7.2, 116), Color = Color3.fromRGB(104, 74, 52), Material = Enum.Material.Wood, Parent = folder })
		part({ Name = "TreeLeaves", Size = Vector3.new(7, 6, 7), CFrame = CFrame.new(side * 30, 12.4, 116), Color = Color3.fromRGB(96, 148, 84), Material = Enum.Material.Grass, Parent = folder })
	end
	-- On the wall beside the corridor opening, not across it. This was a 16
	-- stud board hung in the middle of a 23 stud doorway, so walking in from
	-- the lobby meant walking into a blackboard.
	local crest = part({ Name = "LobbyCrest", Size = Vector3.new(13, 7, 0.5), CFrame = CFrame.new(-18.5, 9, 80.1), Color = Palette.Blackboard, Parent = folder })
	crest.CanCollide = false
	signText(crest, "CRUMBWORTH HIGH\nEST. 1954", Palette.BusYellow, Enum.NormalId.Front)

	buildGrandFacade(folder)
	buildFrontGrounds(folder)
	detailCorridor(folder)

	-- ---------------- outside: entrance, dorms, grounds ----------------
	buildPath(folder, Vector3.new(0, 0, 168), Vector3.new(0, 0, 200), 14)
	buildBus(folder, CFrame.new(-96, 0, 190) * CFrame.Angles(0, math.rad(-4), 0))
	part({ Name = "FrontRoad", Size = Vector3.new(520, 0.4, 22), CFrame = CFrame.new(0, 0.05, 208), Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Asphalt, Parent = folder })
	local dormBeds: { BasePart } = {}
	-- the residential quad: behind the school, either side of the library, with
	-- walks onto the same north path. A dorm parked between the car park and
	-- the road is not a place anyone lives.
	buildDorm(folder, Vector3.new(-176, 0, -212), "Boys Dorm", Color3.fromRGB(70, 130, 220), dormBeds)
	buildDorm(folder, Vector3.new(176, 0, -212), "Girls Dorm", Color3.fromRGB(232, 110, 170), dormBeds)
	buildCampusPath(folder, Vector3.new(-52, 0, -212), Vector3.new(-142, 0, -212), 12)
	buildCampusPath(folder, Vector3.new(52, 0, -212), Vector3.new(142, 0, -212), 12)
	buildPath(folder, Vector3.new(-60, 0, 150), Vector3.new(-130, 0, 192), 8)
	buildPath(folder, Vector3.new(60, 0, 150), Vector3.new(130, 0, 192), 8)
	buildFlagpole(folder)
	buildTreeline(folder, buildTree)
	for _, pos in {
		Vector3.new(-58, 0, 136), Vector3.new(58, 0, 136),
		Vector3.new(-92, 0, 136), Vector3.new(92, 0, 136),
		Vector3.new(-236, 0, 60), Vector3.new(236, 0, 60),
		Vector3.new(-236, 0, -60), Vector3.new(236, 0, -60),
		Vector3.new(-236, 0, 0), Vector3.new(236, 0, 0),
	} do
		buildTree(folder, pos, 1.1 + (math.abs(pos.X) % 3) * 0.12)
	end

	local detentionCenter = Vector3.new(204, 0, 35)

	-- spawn: the bus stop out front
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(20, 0.5, 152)
	spawn.Anchored = true
	spawn.Color = Palette.BusYellow
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Name = "BusStop"
	spawn.Parent = folder

	-- ---------------- campus grounds ----------------
	local LIBRARY = Vector3.new(0, 0, -232)
	local TENNIS = Vector3.new(340, 0, -20)
	local POOL = Vector3.new(-340, 0, -20)
	buildLibrary(folder, LIBRARY)
	buildTennisStadium(folder, TENNIS)
	buildPool(folder, POOL)
	-- walks back to the building, so these read as campus and not scenery
	buildCampusPath(folder, Vector3.new(0, 0, -150), LIBRARY + Vector3.new(0, 0, 44), 16)
	buildCampusPath(folder, Vector3.new(230, 0, -20), TENNIS + Vector3.new(-96, 0, 0), 14)
	buildCampusPath(folder, Vector3.new(-230, 0, -20), POOL + Vector3.new(96, 0, 0), 14)

	-- The treeline predates the pool and the tennis stadium, so it plants
	-- trees inside both. Rather than teach every scatter about every venue,
	-- clear the venues afterwards: one list to extend when a venue is added.
	local KEEP_CLEAR = {
		{ c = POOL, rx = 62, rz = 50, what = "the pool" },
		{ c = TENNIS, rx = 110, rz = 70, what = "the tennis stadium" },
		{ c = LIBRARY, rx = 52, rz = 42, what = "the library" },
	}
	local cleared = 0
	for _, item in folder:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local n = item.Name
		if not (n:find("Tree") or n:find("Conifer") or n:find("Palm") or n:find("Flower") or n:find("Hedge")) then
			continue
		end
		for _, zone in KEEP_CLEAR do
			local offset = item.Position - zone.c
			if math.abs(offset.X) < zone.rx and math.abs(offset.Z) < zone.rz then
				item:Destroy()
				cleared += 1
				break
			end
		end
	end
	if cleared > 0 then
		print(("[MapService] cleared %d plants growing through the new venues"):format(cleared))
	end

	buildUpperFloor(folder)
	furnishSubjectRooms(folder)
	furnishUpperRooms(folder)
	buildTeachersQuarters(folder, Vector3.new(-300, 0, -170))
	buildCampusPath(folder, Vector3.new(-244, 0, -170), Vector3.new(-258, 0, -170), 14)
	buildWayfinding(folder)
	local secretDoor = buildSanctum(folder)
	furnishProps()

	optimize(folder)
	folder.Parent = workspace

	local _ = trophyFloor

	return {
		plots = plots,
		trim = trimRuns,
		props = propRequests,
		library = LIBRARY,
		tennis = TENNIS,
		pool = POOL,
		conveyorStart = Vector3.new(-190, 0, 65),
		conveyorEnd = Vector3.new(190, 0, 65),
		trophyCashBoard = trophyCashBoard,
		trophyAuraBoard = trophyAuraBoard,
		cliqueBoards = cliqueBoards,
		dormBeds = dormBeds,
		detentionSpot = detentionCenter,
		infirmary = Vector3.new(122, 17, -94),
		secretDoor = secretDoor,
		sanctumSpawn = SANCTUM_CENTRE + Vector3.new(0, 6, 62),
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
