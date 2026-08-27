--!strict
-- The HUD grid.
--
-- Two sizing bugs got us here, both the same mistake in different clothes:
-- guessing at the size of the screen. First Layout read
-- workspace.CurrentCamera before it had a viewport and fell back to 1x, so
-- everything rendered about three times too big. Then it read ViewportSize,
-- which on a high-density phone reports device pixels while GUI offsets live
-- in a smaller space — about 2.3x smaller on the device we were testing.
--
-- The only thing that is authoritative for GUI offsets is a ScreenGui's own
-- AbsoluteSize, so that is what we measure. And wherever it is possible, sizes
-- are expressed as a straight fraction of the parent instead, which needs no
-- measurement at all: UDim2.new(0, 0, 0.055, 0) is 5.5% of the screen, always,
-- on every device, with nothing left to get wrong.

local Players = game:GetService("Players")

local Layout = {}

local VH = 720
local VW = 1280

do
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local probe = Instance.new("ScreenGui")
	probe.Name = "LayoutProbe"
	probe.ResetOnSpawn = false
	probe.IgnoreGuiInset = false
	probe.Enabled = false
	probe.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = probe
	for _ = 1, 120 do
		if frame.AbsoluteSize.Y > 50 then
			break
		end
		task.wait(0.03)
	end
	if frame.AbsoluteSize.Y > 50 then
		VH = frame.AbsoluteSize.Y
		VW = frame.AbsoluteSize.X
	end
	probe:Destroy()
end

Layout.ViewportHeight = VH
Layout.ViewportWidth = VW

-- Pixels from a fraction of screen height. Height rather than width: a phone in
-- landscape is very wide and very short, so sizing off width makes everything
-- enormous on exactly the device with least room.
function Layout.h(fraction: number): number
	return math.max(1, math.floor(VH * fraction + 0.5))
end

function Layout.w(fraction: number): number
	return math.max(1, math.floor(VW * fraction + 0.5))
end

-- Text scales to its box, with a ceiling so a big screen does not get a poster.
function Layout.FitText(label: GuiObject, maxFraction: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = math.clamp(math.floor(VH * maxFraction + 0.5), 10, 34)
	constraint.MinTextSize = 8
	constraint.Parent = label
end

-- Force a square (or any ratio); the element is then sized by height alone.
function Layout.Ratio(object: GuiObject, ratio: number?)
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio or 1
	constraint.DominantAxis = Enum.DominantAxis.Height
	constraint.Parent = object
end

-- ---- the grid, all as fractions of screen height ----
Layout.MarginScale = 0.03
Layout.Margin = Layout.h(0.03)

Layout.MinimapScale = 0.19
Layout.Minimap = Layout.h(Layout.MinimapScale)

Layout.PillHeight = 0.058
Layout.RailIcon = 0.10
Layout.RailGap = 0.016

Layout.ButtonScale = 0.115
Layout.ToyButtonScale = 0.135
Layout.ChipScale = 0.075

-- the thumb cluster sits above Roblox's own jump control
Layout.BarBottom = 0.30

Layout.Order = {
	Sprint = 10,
	Punch = 20,
	Toy = 30,
}

local function makeRow(gui: Instance, name: string, heightScale: number, bottomScale: number): Frame
	local existing = gui:FindFirstChild(name)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local row = Instance.new("Frame")
	row.Name = name
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.new(1, -Layout.Margin, 1 - bottomScale, 0)
	row.Size = UDim2.new(0, 0, heightScale, 0)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	row.ZIndex = 30
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, Layout.h(0.018))
	list.Parent = row
	return row
end

function Layout.ActionBar(gui: ScreenGui): Frame
	return makeRow(gui, "ActionBar", Layout.ToyButtonScale, Layout.BarBottom)
end

function Layout.ChipRow(gui: ScreenGui): Frame
	return makeRow(gui, "ChipRow", Layout.ChipScale, Layout.BarBottom + Layout.ToyButtonScale + 0.014)
end

-- Legacy helper: still used by the panels, now against a real measurement.
function Layout.px(n: number): number
	return math.max(1, math.floor(n / 900 * VH + 0.5))
end

function Layout.TextSize(fraction: number): number
	return math.clamp(math.floor(VH * fraction + 0.5), 9, 34)
end

Layout.Scale = VH / 900
Layout.StatusX = Layout.Margin + Layout.Minimap + Layout.h(0.02)
Layout.PanelWidth = Layout.w(0.2)

return Layout
