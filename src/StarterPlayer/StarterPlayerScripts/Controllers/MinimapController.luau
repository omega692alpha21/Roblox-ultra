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
	{ x = 0, z = -135, w = 104, d = 26, color = Color3.fromRGB(72, 78, 92) }, -- gym block
	{ x = -116, z = 0, w = 112, d = 104, color = Color3.fromRGB(86, 132, 74) }, -- west courtyard
	{ x = 116, z = 0, w = 112, d = 104, color = Color3.fromRGB(86, 132, 74) }, -- east courtyard
	{ x = 0, z = 70, w = 448, d = 22, color = Color3.fromRGB(148, 154, 168) }, -- main corridor
	{ x = 0, z = 100, w = 120, d = 48, color = Color3.fromRGB(120, 126, 142) }, -- lobby
	{ x = 0, z = 164, w = 26, d = 80, color = Color3.fromRGB(176, 172, 160) }, -- entrance walk
	{ x = -132, z = 170, w = 120, d = 62, color = Color3.fromRGB(58, 60, 66) }, -- west lot
	{ x = 132, z = 170, w = 120, d = 62, color = Color3.fromRGB(58, 60, 66) }, -- east lot
	{ x = 0, z = 208, w = 520, d = 22, color = Color3.fromRGB(48, 50, 56) }, -- road
	{ x = -176, z = -212, w = 64, d = 54, color = Color3.fromRGB(92, 76, 68) }, -- boys dorm
	{ x = 176, z = -212, w = 64, d = 54, color = Color3.fromRGB(92, 76, 68) }, -- girls dorm
	{ x = 0, z = -232, w = 92, d = 68, color = Color3.fromRGB(150, 142, 128) }, -- library
	{ x = 340, z = -20, w = 190, d = 110, color = Color3.fromRGB(58, 104, 88) }, -- tennis
	{ x = -340, z = -20, w = 120, d = 88, color = Color3.fromRGB(96, 168, 200) }, -- pool
}

type Marker = { x: number, z: number, icon: string, color: Color3 }
local MARKERS: { Marker } = {
	{ x = 0, z = -105, icon = "🏀", color = Color3.fromRGB(255, 196, 80) },
	{ x = -204, z = -29, icon = "🍔", color = Color3.fromRGB(255, 214, 120) },
	{ x = -204, z = 35, icon = "🏛️", color = Color3.fromRGB(190, 214, 255) },
	{ x = 204, z = -29, icon = "🏆", color = Color3.fromRGB(255, 232, 140) },
	{ x = 204, z = 35, icon = "🔒", color = Color3.fromRGB(255, 120, 110) },
	{ x = -74, z = -94, icon = "➗", color = Color3.fromRGB(120, 176, 255) },
	{ x = 74, z = -94, icon = "🎵", color = Color3.fromRGB(212, 160, 240) },
	{ x = -116, z = -28, icon = "🧬", color = Color3.fromRGB(150, 220, 130) },
	{ x = 0, z = -232, icon = "📚", color = Color3.fromRGB(240, 226, 190) },
	{ x = 340, z = -20, icon = "🎾", color = Color3.fromRGB(200, 240, 120) },
	{ x = -340, z = -20, icon = "🏊", color = Color3.fromRGB(140, 216, 240) },
	{ x = 116, z = -28, icon = "⚗️", color = Color3.fromRGB(150, 240, 190) },
	{ x = -116, z = 0, icon = "👥", color = Color3.fromRGB(180, 255, 200) },
}

function MinimapController.Init(gui: ScreenGui)
	-- lives in the shared HUD gui so an open panel covers it instead of the
	-- map floating on top of every menu
	local frame = Instance.new("Frame")
	frame.Name = "Minimap"
	frame.Position = UDim2.new(0, Layout.Margin, Layout.MarginScale, 0)
	frame.Size = UDim2.new(0, 0, Layout.MinimapScale, 0)
	Layout.Ratio(frame, 1)
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

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		if not root or not camera then
			return
		end
		local pos = root.Position
		local yaw = 0
		if MAP_ROT then
			local look = camera.CFrame.LookVector
			yaw = math.atan2(look.X, look.Z)
		end
		world.Rotation = math.deg(yaw)
		north.Rotation = math.deg(yaw)

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
