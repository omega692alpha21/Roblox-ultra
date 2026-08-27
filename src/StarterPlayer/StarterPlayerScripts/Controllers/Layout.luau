--!strict
-- One layout grid for the whole HUD.
--
-- Every on-screen element used to pick its own absolute position, so the
-- minimap sat on the nav rail, PUNCH sat on the toy button, and three build
-- stamps fought over the corners. Everything now claims a slot here instead,
-- and the crowded bottom-right corner is a real container with a layout
-- rather than a pile of hand-placed offsets.
--
--   top-left     minimap, then one status card beside it
--   top-right    lock timer, then notifications below it
--   bottom-left  the single MENU button
--   bottom-right the action bar (RUN / PUNCH / THROW) with toy chips above

local Layout = {}

Layout.Minimap = 128
Layout.Margin = 12
-- x where anything to the right of the minimap starts
Layout.StatusX = Layout.Margin + Layout.Minimap + 8

-- Buttons sit in a single right-aligned row so they can never stack on top of
-- one another. Lower LayoutOrder ends up further left.
Layout.Order = {
	Sprint = 10,
	Punch = 20,
	Toy = 30,
}

local BAR_HEIGHT = 84
local BAR_BOTTOM = 132 -- clear of Roblox's own jump button, which owns the corner

local function makeRow(gui: ScreenGui, name: string, height: number, bottom: number): Frame
	local existing = gui:FindFirstChild(name)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local row = Instance.new("Frame")
	row.Name = name
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.new(1, -18, 1, -bottom)
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
	list.Padding = UDim.new(0, 10)
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
	return makeRow(gui, "ChipRow", 40, BAR_BOTTOM + BAR_HEIGHT + 8)
end

return Layout
