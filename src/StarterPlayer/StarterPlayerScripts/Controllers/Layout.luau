--!strict
-- The HUD grid, measured as fractions of the real viewport.
--
-- Sizing in "points" and hoping was the bug: a status card authored against a
-- guessed reference height came out a third of the screen wide on a phone.
-- Everything here is derived from the camera's actual ViewportSize, so
-- "the cash chip is 5% of screen height" is exactly what renders, on any
-- device, with no conversion to get wrong.
--
-- The shape follows what the big Roblox social games do: the middle of the
-- screen is empty, status hugs the top, menus are a rail of icons on the right
-- edge, thumb buttons sit bottom-right above Roblox's own jump control.

local Layout = {}

local VH = 720
local VW = 1280

do
	local camera = workspace.CurrentCamera
	-- the viewport can still be (0, 0) on the first frames of a mobile join
	for _ = 1, 60 do
		if camera and camera.ViewportSize.Y > 50 then
			break
		end
		task.wait(0.05)
		camera = workspace.CurrentCamera
	end
	if camera and camera.ViewportSize.Y > 50 then
		VH = camera.ViewportSize.Y
		VW = camera.ViewportSize.X
	end
end

Layout.ViewportHeight = VH
Layout.ViewportWidth = VW

-- Pixels from a fraction of viewport height. Height, not width, because a
-- phone in landscape is very wide and very short: sizing off width makes
-- everything enormous on exactly the device that has least room.
function Layout.h(fraction: number): number
	return math.floor(VH * fraction + 0.5)
end

function Layout.w(fraction: number): number
	return math.floor(VW * fraction + 0.5)
end

-- Text that fits its box, with a ceiling so it never turns into a billboard.
function Layout.TextSize(fraction: number): number
	return math.clamp(math.floor(VH * fraction + 0.5), 9, 48)
end

Layout.Margin = Layout.h(0.028)
Layout.Minimap = Layout.h(0.17)

-- the right-edge menu rail
Layout.RailIcon = Layout.h(0.115)
Layout.RailGap = Layout.h(0.018)

-- thumb buttons, bottom right, clear of Roblox's jump control
Layout.ButtonSize = Layout.h(0.135)
Layout.ToyButtonSize = Layout.h(0.155)
Layout.ChipSize = Layout.h(0.085)

Layout.Order = {
	Sprint = 10,
	Punch = 20,
	Toy = 30,
}

local BAR_BOTTOM = Layout.h(0.30)

local function makeRow(gui: Instance, name: string, height: number, bottom: number): Frame
	local existing = gui:FindFirstChild(name)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local row = Instance.new("Frame")
	row.Name = name
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.new(1, -Layout.Margin, 1, -bottom)
	row.Size = UDim2.fromOffset(0, height)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	row.ZIndex = 30
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, Layout.h(0.02))
	list.Parent = row
	return row
end

function Layout.ActionBar(gui: ScreenGui): Frame
	return makeRow(gui, "ActionBar", Layout.ToyButtonSize, BAR_BOTTOM)
end

function Layout.ChipRow(gui: ScreenGui): Frame
	return makeRow(gui, "ChipRow", Layout.ChipSize, BAR_BOTTOM + Layout.ToyButtonSize + Layout.h(0.015))
end

-- Kept so existing call sites keep working; a "px" is now a fraction of the
-- 900-tall reference expressed against the real viewport.
function Layout.px(n: number): number
	return math.floor(n / 900 * VH + 0.5)
end

Layout.Scale = VH / 900
Layout.StatusX = Layout.Margin + Layout.Minimap + Layout.h(0.02)
Layout.PanelWidth = Layout.w(0.2)

return Layout
