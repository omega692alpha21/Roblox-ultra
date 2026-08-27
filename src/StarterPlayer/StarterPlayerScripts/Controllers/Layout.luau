--!strict
-- One layout grid for the whole HUD, sized to the device.
--
-- Every offset here is authored against a 640pt-tall reference screen and then
-- scaled. A phone in landscape reports roughly 380pt of height, so unscaled
-- desktop sizes turn a 128pt minimap into a third of the screen and a status
-- card into a billboard across the player's face. Everything measured in
-- px() shrinks with the viewport; edge margins stay real so anchoring to a
-- corner still means the corner.
--
--   top-left     minimap, then a thin status strip beside it
--   top-right    lock chip
--   bottom-left  the single MENU button
--   bottom-right the action bar (RUN / PUNCH / THROW), toy chips just above

local Layout = {}

local REFERENCE_HEIGHT = 640

local function computeScale(): number
	local camera = workspace.CurrentCamera
	local height = camera and camera.ViewportSize.Y or 0
	if height < 120 then
		return 1
	end
	return math.clamp(height / REFERENCE_HEIGHT, 0.55, 1.15)
end

Layout.Scale = computeScale()

function Layout.px(n: number): number
	return math.floor(n * Layout.Scale + 0.5)
end

Layout.Margin = Layout.px(12)
Layout.Minimap = Layout.px(112)
-- x where anything to the right of the minimap starts
Layout.StatusX = Layout.Margin + Layout.Minimap + Layout.px(8)

-- Buttons sit in a single right-aligned row so they can never stack on top of
-- one another. Lower LayoutOrder ends up further left.
Layout.Order = {
	Sprint = 10,
	Punch = 20,
	Toy = 30,
}

Layout.ButtonSize = Layout.px(62)
Layout.ToyButtonSize = Layout.px(70)
Layout.ChipSize = Layout.px(38)

local BAR_HEIGHT = Layout.ToyButtonSize
-- clear of Roblox's own jump button, which owns the very corner
local BAR_BOTTOM = Layout.px(104)
local CHIP_HEIGHT = Layout.px(32)

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
	list.Padding = UDim.new(0, Layout.px(10))
	list.Parent = row
	return row
end

-- The bottom-right action bar, created on first use and shared by every
-- controller that wants a thumb button.
function Layout.ActionBar(gui: ScreenGui): Frame
	return makeRow(gui, "ActionBar", BAR_HEIGHT, BAR_BOTTOM)
end

-- A strip directly above the action bar, for the toy chips.
function Layout.ChipRow(gui: ScreenGui): Frame
	return makeRow(gui, "ChipRow", CHIP_HEIGHT, BAR_BOTTOM + BAR_HEIGHT + Layout.px(6))
end

return Layout
