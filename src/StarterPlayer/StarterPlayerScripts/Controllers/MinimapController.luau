--!strict
-- A GTA-style minimap: the campus drawn to scale in the corner, rotating under
-- a fixed player arrow, with live blips for everyone else and labelled markers
-- for the places that matter.
--
-- Drawn with plain Frames rather than a ViewportFrame — it costs almost
-- nothing on a phone and reads clearly at small size.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Layout = require(script.Parent.Layout)

local MinimapController = {}

local player = Players.LocalPlayer

-- The dial is sized as a fraction of the screen and kept square by a ratio
-- constraint, so nothing here depends on guessing a pixel count. The studs to
-- pixels factor is read back off its real AbsoluteSize once it exists.
-- Studs visible across the dial. Everything inside is positioned in scale
-- units relative to the dial, so the map is correct at any size without a
-- single pixel measurement.
local SPAN = 520
local MAP_ROT = true -- rotate the map under the arrow, GTA style

type Shape = { x: number, z: number, w: number, d: number, color: Color3, z2: number? }

-- the campus, from MapService's floor plan
local SHAPES: { Shape } = {
	{ x = 0, z = -12, w = 452, d = 252, color = Color3.fromRGB(72, 78, 92) }, -- building mass
	{ x = 425, z = 405, w = 190, d = 130, color = Color3.fromRGB(72, 78, 92) }, -- gymnasium
	{ x = 320, z = -300, w = 200, d = 96, color = Color3.fromRGB(72, 78, 92) }, -- cafeteria
	{ x = -400, z = 20, w = 170, d = 120, color = Color3.fromRGB(72, 78, 92) }, -- detention hall
	{ x = -320, z = -300, w = 200, d = 96, color = Color3.fromRGB(72, 78, 92) }, -- library
	{ x = -116, z = 0, w = 112, d = 104, color = Color3.fromRGB(86, 132, 74) }, -- west courtyard
	{ x = 116, z = 0, w = 112, d = 104, color = Color3.fromRGB(86, 132, 74) }, -- east courtyard
	{ x = 0, z = 70, w = 448, d = 22, color = Color3.fromRGB(148, 154, 168) }, -- main corridor
	{ x = 0, z = 100, w = 120, d = 48, color = Color3.fromRGB(120, 126, 142) }, -- lobby
	-- The front of the campus, as drawn: the Great Court is 300 x 150 centred
	-- on (0, 210) with the road behind it at z = 320 and the main gate at 550.
	-- These were the entrance walk, two car parks either side of it and a road
	-- at z = 208 -- the layout that stood here before the court was built, so
	-- the minimap showed a campus the player could not walk out of the door
	-- into.
	{ x = 0, z = 210, w = 300, d = 150, color = Color3.fromRGB(96, 98, 108) }, -- great court
	{ x = 0, z = 210, w = 26, d = 150, color = Color3.fromRGB(176, 172, 160) }, -- entrance walk
	{ x = 0, z = 210, w = 300, d = 26, color = Color3.fromRGB(176, 172, 160) }, -- cross walk
	{ x = 430, z = 40, w = 180, d = 140, color = Color3.fromRGB(58, 60, 66) }, -- car park
	{ x = 0, z = 320, w = 520, d = 22, color = Color3.fromRGB(48, 50, 56) }, -- road
	{ x = 0, z = 550, w = 100, d = 26, color = Color3.fromRGB(120, 118, 112) }, -- main gate
	{ x = -430, z = 330, w = 240, d = 200, color = Color3.fromRGB(52, 54, 60) }, -- bike track
	{ x = 440, z = 235, w = 280, d = 170, color = Color3.fromRGB(74, 118, 66) }, -- sports field
	{ x = 0, z = -310, w = 300, d = 120, color = Color3.fromRGB(92, 76, 68) }, -- boarding house
	{ x = 390, z = -160, w = 280, d = 120, color = Color3.fromRGB(70, 96, 74) }, -- ball courts
}

type Marker = { x: number, z: number, icon: string, color: Color3 }
local MARKERS: { Marker } = {
	{ x = 425, z = 437, icon = "🏀", color = Color3.fromRGB(255, 196, 80) },
	{ x = 372, z = -300, icon = "🍔", color = Color3.fromRGB(255, 214, 120) },
	{ x = -204, z = 35, icon = "🏛️", color = Color3.fromRGB(190, 214, 255) },
	{ x = 204, z = -29, icon = "🏆", color = Color3.fromRGB(255, 232, 140) },
	{ x = -438, z = -14, icon = "🔒", color = Color3.fromRGB(255, 120, 110) },
	{ x = -74, z = -94, icon = "➗", color = Color3.fromRGB(120, 176, 255) },
	{ x = 74, z = -94, icon = "🎵", color = Color3.fromRGB(212, 160, 240) },
	{ x = -116, z = -28, icon = "🧬", color = Color3.fromRGB(150, 220, 130) },
	{ x = -320, z = -300, icon = "📚", color = Color3.fromRGB(240, 226, 190) },
	{ x = 116, z = -28, icon = "⚗️", color = Color3.fromRGB(150, 240, 190) },
	{ x = -116, z = 0, icon = "👥", color = Color3.fromRGB(180, 255, 200) },
	{ x = -300, z = -170, icon = "🎓", color = Color3.fromRGB(226, 186, 120) }, -- teachers' quarters
	{ x = 0, z = -310, icon = "🛏️", color = Color3.fromRGB(200, 190, 240) },
	{ x = 0, z = 210, icon = "⛲", color = Color3.fromRGB(180, 220, 255) },
	{ x = -430, z = 330, icon = "🚲", color = Color3.fromRGB(230, 210, 150) },
	{ x = 0, z = 550, icon = "🚏", color = Color3.fromRGB(240, 220, 160) },
}

function MinimapController.Init(gui: ScreenGui)
	-- lives in the shared HUD gui so an open panel covers it instead of the
	-- map floating on top of every menu
	local frame = Instance.new("Frame")
	frame.Name = "Minimap"
	-- top right, under Roblox's avatar chip. It used to sit top left, where it
	-- shared a band with everything else the player had to read.
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.fromScale(1 - Layout.EdgeX, Layout.MinimapY)
	Layout.Square(frame, Layout.MinimapH)
	frame.BackgroundColor3 = Color3.fromRGB(28, 34, 42)
	frame.BackgroundTransparency = 0.08
	frame.ClipsDescendants = true
	frame.ZIndex = 20
	frame.Parent = gui
	-- a rounded panel, not a circle: UICorner does not clip descendants, so a
	-- circular frame just left the square map poking out past the ring
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.14, 0)
	round.Parent = frame
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(245, 197, 49)
	ring.Thickness = 2
	ring.Parent = frame

	-- the world, drawn once and then moved/rotated as a single layer
	local world = Instance.new("Frame")
	world.Name = "World"
	world.AnchorPoint = Vector2.new(0.5, 0.5)
	world.Position = UDim2.fromScale(0.5, 0.5)
	world.Size = UDim2.fromScale(1, 1)
	world.BackgroundTransparency = 1
	world.ZIndex = 21
	world.Parent = frame

	for _, shape in SHAPES do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5 + shape.x / SPAN, 0.5 + shape.z / SPAN)
		piece.Size = UDim2.fromScale(shape.w / SPAN, shape.d / SPAN)
		piece.BackgroundColor3 = shape.color
		piece.BorderSizePixel = 0
		piece.ZIndex = 21
		piece.Parent = world
	end

	for _, marker in MARKERS do
		local dot = Instance.new("TextLabel")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5 + marker.x / SPAN, 0.5 + marker.z / SPAN)
		dot.Size = UDim2.fromScale(0.13, 0.13)
		dot.BackgroundTransparency = 1
		dot.Text = marker.icon
		dot.TextScaled = true
		dot.ZIndex = 23
		dot.Parent = world
	end

	-- blips for everyone else, pooled
	local blips: { [Player]: Frame } = {}
	local function blipFor(other: Player): Frame
		local existing = blips[other]
		if existing then
			return existing
		end
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromScale(0.07, 0.07)
		dot.BackgroundColor3 = Color3.fromRGB(255, 108, 96)
		dot.BorderSizePixel = 0
		dot.ZIndex = 24
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = dot
		dot.Parent = world
		blips[other] = dot
		return dot
	end
	Players.PlayerRemoving:Connect(function(other)
		local dot = blips[other]
		if dot then
			dot:Destroy()
			blips[other] = nil
		end
	end)

	-- home: the player's own collect pad, so "go collect" points somewhere
	local home = Instance.new("TextLabel")
	home.Name = "Home"
	home.AnchorPoint = Vector2.new(0.5, 0.5)
	home.Size = UDim2.fromScale(0.13, 0.13)
	home.BackgroundTransparency = 1
	home.Text = "🏠"
	home.TextScaled = true
	home.Visible = false
	home.ZIndex = 25
	home.Parent = world

	local function refreshHome()
		local pad = player:GetAttribute("HomePad")
		if typeof(pad) == "Vector3" then
			home.Visible = true
			home.Position = UDim2.fromScale(0.5 + pad.X / SPAN, 0.5 + pad.Z / SPAN)
		else
			home.Visible = false
		end
	end
	player:GetAttributeChangedSignal("HomePad"):Connect(refreshHome)
	refreshHome()

	-- the player arrow sits dead centre and never moves
	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromScale(0.17, 0.17)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "▲"
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(255, 244, 220)
	arrow.TextStrokeTransparency = 0.3
	arrow.ZIndex = 26
	arrow.Parent = frame

	-- north pip on the ring
	local north = Instance.new("TextLabel")
	north.AnchorPoint = Vector2.new(0.5, 0)
	north.Position = UDim2.new(0.5, 0, 0, 2)
	north.Size = UDim2.fromScale(0.11, 0.11)
	north.BackgroundTransparency = 1
	north.Font = Enum.Font.FredokaOne
	north.Text = "N"
	north.TextScaled = true
	north.TextColor3 = Color3.fromRGB(245, 197, 49)
	north.ZIndex = 26
	north.Parent = frame

	-- A compass ribbon above the map. The map itself rotates, which tells you
	-- where things are; the ribbon tells you which way you are pointing, which
	-- is the question you actually ask before you set off down a corridor.
	local compass = Instance.new("Frame")
	compass.Name = "Compass"
	compass.AnchorPoint = Vector2.new(1, 0)
	compass.Position = UDim2.fromScale(1 - Layout.EdgeX, Layout.CompassY)
	compass.Size = UDim2.fromScale(Layout.CompassW, Layout.CompassH)
	compass.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	compass.BackgroundTransparency = 0.35
	compass.ClipsDescendants = true
	compass.ZIndex = 20
	compass.Parent = gui
	local compassRound = Instance.new("UICorner")
	compassRound.CornerRadius = UDim.new(0.4, 0)
	compassRound.Parent = compass

	local HEADINGS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	local ticks: { TextLabel } = {}
	for index, name in HEADINGS do
		local tick = Instance.new("TextLabel")
		tick.Name = "Tick" .. name
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Size = UDim2.fromScale(0.14, 0.9)
		tick.BackgroundTransparency = 1
		tick.Font = Enum.Font.FredokaOne
		tick.Text = name
		tick.TextScaled = true
		tick.TextColor3 = if name == "N" then Color3.fromRGB(245, 197, 49) else Color3.fromRGB(226, 230, 238)
		tick.ZIndex = 21
		tick.Parent = compass
		ticks[index] = tick
	end
	-- the heading you are on, marked in the middle
	local needle = Instance.new("Frame")
	needle.AnchorPoint = Vector2.new(0.5, 1)
	needle.Position = UDim2.fromScale(0.5, 1)
	needle.Size = UDim2.fromScale(0.006, 0.5)
	needle.BackgroundColor3 = Color3.fromRGB(245, 197, 49)
	needle.BorderSizePixel = 0
	needle.ZIndex = 22
	needle.Parent = compass

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		if not root or not camera then
			return
		end
		local pos = root.Position
		local look = camera.CFrame.LookVector
		local yaw = if MAP_ROT then math.atan2(look.X, look.Z) else 0
		world.Rotation = math.deg(yaw)
		north.Rotation = math.deg(yaw)

		-- the ribbon shows 180 degrees at a time, so a heading is half a turn
		-- from either edge and nothing ever pops in at the centre
		local heading = math.deg(math.atan2(-look.X, -look.Z)) % 360
		for index, tick in ticks do
			local bearing = (index - 1) * 45
			local delta = (bearing - heading + 540) % 360 - 180
			tick.Position = UDim2.fromScale(0.5 + delta / 180, 0.5)
			tick.Visible = math.abs(delta) < 95
		end

		-- offset the world so the player's world position lands at the centre
		local cosY, sinY = math.cos(yaw), math.sin(yaw)
		local px, pz = -pos.X / SPAN, -pos.Z / SPAN
		world.Position = UDim2.fromScale(0.5 + (px * cosY - pz * sinY), 0.5 + (px * sinY + pz * cosY))

		for _, other in Players:GetPlayers() do
			if other ~= player then
				local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local dot = blipFor(other)
				if otherRoot then
					dot.Visible = true
					dot.Position = UDim2.fromScale(
						0.5 + otherRoot.Position.X / SPAN,
						0.5 + otherRoot.Position.Z / SPAN
					)
				else
					dot.Visible = false
				end
			end
		end
	end)
end

return MinimapController
