--!strict
-- The HUD zone map.
--
-- Sizing has bitten three times now, each time from measuring the screen
-- wrong: the camera before it had a viewport (fell back to 1x), ViewportSize
-- on a high-density phone (device pixels, not GUI units), and a probe
-- ScreenGui that was disabled and so never laid out. The fix is to measure the
-- one thing that cannot be wrong — the AbsoluteSize of the very ScreenGui the
-- HUD is parented to — and to express everything after that in plain pixels.
--
-- No scale-inside-scale anywhere. A fraction is only unambiguous against a
-- parent whose size is already settled, and every time I nested one inside
-- another something collapsed to nothing or doubled.
--
-- The zones below are laid out so they cannot touch. Anything new goes in a
-- zone, or gets a new one carved out here.
--
--   top-left      minimap                       y 0.03 – 0.23
--   left edge     menu rail (5 tiles)           y 0.27 – 0.81
--   top-centre    status pills                  y 0.03 – 0.09
--   top-centre    goal chip                     y 0.10 – 0.16
--   right edge    tool rail (3 tiles)           y 0.20 – 0.57
--   bottom-right  run / punch / throw           y 0.83 – 0.96, left of jump
--   centre        the reticle, and nothing else

local Players = game:GetService("Players")

local Layout = {}

local VH = 720
local VW = 1280

-- Called once by the client bootstrap with the real HUD ScreenGui, before any
-- controller builds anything.
function Layout.Attach(gui: ScreenGui)
	for _ = 1, 150 do
		if gui.AbsoluteSize.Y > 50 then
			break
		end
		task.wait(0.03)
	end
	if gui.AbsoluteSize.Y > 50 then
		VH = gui.AbsoluteSize.Y
		VW = gui.AbsoluteSize.X
	end
	Layout.ViewportHeight = VH
	Layout.ViewportWidth = VW
end

do
	-- a fallback for anything that reads Layout before Attach runs
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local camera = workspace.CurrentCamera
	if playerGui and camera and camera.ViewportSize.Y > 50 then
		VH = camera.ViewportSize.Y
		VW = camera.ViewportSize.X
	end
end

Layout.ViewportHeight = VH
Layout.ViewportWidth = VW

-- Pixels from a fraction of screen height. Height, not width: a phone in
-- landscape is very wide and very short, and sizing off width makes everything
-- enormous on exactly the device with least room.
function Layout.h(fraction: number): number
	return math.max(1, math.floor(VH * fraction + 0.5))
end

function Layout.w(fraction: number): number
	return math.max(1, math.floor(VW * fraction + 0.5))
end

function Layout.Square(fraction: number): UDim2
	local side = Layout.h(fraction)
	return UDim2.fromOffset(side, side)
end

-- Text fits its box, with a ceiling so a big screen does not get a poster.
function Layout.FitText(label: GuiObject, maxFraction: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = math.clamp(math.floor(VH * maxFraction + 0.5), 10, 40)
	constraint.MinTextSize = 7
	constraint.Parent = label
end

-- ---- the zones ----
Layout.EdgeX = 0.014 -- side margin, as a fraction of WIDTH
Layout.Margin = 0 -- filled in below, in pixels

Layout.MinimapTop = 0.03
Layout.MinimapSize = 0.20

Layout.PillTop = 0.03
Layout.PillHeight = 0.058

Layout.GoalTop = 0.10
Layout.GoalHeight = 0.055

Layout.RailTile = 0.095
Layout.RailGap = 0.014
Layout.MenuRailTop = 0.27
Layout.ToolRailTop = 0.20

Layout.ButtonSize = 0.125
Layout.ToyButtonSize = 0.145
Layout.ActionBottom = 0.04
-- how much of the right edge Roblox's own jump control needs
Layout.JumpClearance = 0.34

Layout.Order = {
	Sprint = 10,
	Punch = 20,
	Toy = 30,
}

function Layout.Init()
	Layout.Margin = Layout.w(Layout.EdgeX)
end

-- A vertical column of square tiles pinned to one edge at a fixed top.
function Layout.Rail(gui: Instance, name: string, side: string, tiles: number): Frame
	local existing = gui:FindFirstChild(name)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local tile = Layout.h(Layout.RailTile)
	local gap = Layout.h(Layout.RailGap)
	local top = side == "left" and Layout.MenuRailTop or Layout.ToolRailTop
	local margin = Layout.w(Layout.EdgeX)
	local rail = Instance.new("Frame")
	rail.Name = name
	rail.AnchorPoint = Vector2.new(side == "left" and 0 or 1, 0)
	rail.Position = UDim2.new(
		side == "left" and 0 or 1,
		side == "left" and margin or -margin,
		0,
		Layout.h(top)
	)
	rail.Size = UDim2.fromOffset(tile, tile * tiles + gap * math.max(0, tiles - 1))
	rail.BackgroundTransparency = 1
	rail.ZIndex = 28
	rail.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, gap)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rail
	return rail
end

-- The thumb row: along the bottom, clear of Roblox's jump control.
function Layout.ActionBar(gui: ScreenGui): Frame
	local existing = gui:FindFirstChild("ActionBar")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local height = Layout.h(Layout.ToyButtonSize)
	local gap = Layout.h(0.03)
	local row = Instance.new("Frame")
	row.Name = "ActionBar"
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.new(1, -Layout.h(Layout.JumpClearance), 1, -Layout.h(Layout.ActionBottom))
	row.Size = UDim2.fromOffset(height * 3 + gap * 2, height)
	row.BackgroundTransparency = 1
	row.ZIndex = 30
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	list.Parent = row
	return row
end

-- Legacy helper, still used by the modal panels.
function Layout.px(n: number): number
	return math.max(1, math.floor(n / 900 * VH + 0.5))
end

function Layout.TextSize(fraction: number): number
	return math.clamp(math.floor(VH * fraction + 0.5), 9, 34)
end

Layout.Init()
Layout.Scale = VH / 900
Layout.PanelWidth = Layout.w(0.2)

return Layout
