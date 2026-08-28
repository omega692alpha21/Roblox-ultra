--!strict
-- The HUD layout, in Scale only.
--
-- Sizing has been wrong four times, every time because I tried to convert a
-- fraction of the screen into pixels and got the screen size wrong: the camera
-- before it had a viewport, ViewportSize on a high-density phone, a probe
-- ScreenGui that was disabled, and finally an AbsoluteSize that still did not
-- match what rendered.
--
-- So there is no measurement any more. A UDim2 Scale is *defined* as a
-- fraction of the parent's absolute size, whatever that turns out to be, so
-- UDim2.fromScale(0.36, 0.05) is 36% by 5% of the screen on every device and
-- there is nothing left for me to get wrong.
--
-- Two rules that took four builds to learn:
--
--   1. Scale is only unambiguous against a parent whose own size is settled.
--      Every element here is either a direct child of the HUD ScreenGui, or a
--      child of a container that is itself sized in screen Scale — and the
--      composition is written out in the comments so it can be checked.
--   2. A square is fromScale(1, f) plus an aspect constraint, never
--      fromScale(0, f). AspectType.FitWithinMaxSize treats Size as a bounding
--      box, so a width of 0 collapses the element to nothing. That is what
--      made the minimap and the throw button disappear.
--
-- Roblox owns four corners of a phone screen before we place anything:
--
--   top-left      menu / chat / mic pill      x .04-.30  y .02-.13
--   top-right     player thumbnail            x .92-1.0  y .02-.16
--   bottom-left   movement thumbstick         x  0 -.24  y .70-1.0
--   bottom-right  jump and emote              x .80-1.0  y .66-1.0
--
-- Our zones live in the gaps and nowhere else. tools/hud_zonecheck.py reads
-- the numbers below and fails if any two of them touch.

local Layout = {}

-- ---------------- reserved: Roblox's own controls ----------------
Layout.Reserved = {
	topbar = { 0.04, 0.02, 0.30, 0.13 },
	avatar = { 0.92, 0.02, 1.00, 0.16 },
	thumbstick = { 0.00, 0.70, 0.24, 1.00 },
	jump = { 0.80, 0.66, 1.00, 1.00 },
}

Layout.EdgeX = 0.014

-- ---------------- top centre ----------------
-- below Roblox's topbar, not beside it: a centred row wide enough to read
-- would otherwise run under the menu / chat pill
Layout.PillsY = 0.15
Layout.PillsW = 0.50
Layout.PillsH = 0.05
Layout.PillW = 0.23 -- of the pill row
Layout.PillGap = 0.012 -- of the pill row

Layout.GoalY = 0.215
Layout.GoalW = 0.42
Layout.GoalH = 0.048

-- the House Cup chip, under the goal: your house, where it stands and how long
-- is left in the term, on screen the whole time. A score only visible in a
-- menu is a score nobody competes over.
Layout.HouseY = 0.275
Layout.HouseW = 0.26
Layout.HouseH = 0.042

-- ---------------- top right: the minimap ----------------
-- Under Roblox's avatar chip, not beside it. The compass ticks ride on the
-- top edge of the same square.
Layout.MinimapY = 0.19
Layout.MinimapH = 0.17 -- square, so 0.17 of height

-- the compass ribbon sits under the map, not over it: above the map is
-- Roblox's avatar chip on one side and our own status pills on the other
Layout.CompassY = 0.375
Layout.CompassW = 0.22
Layout.CompassH = 0.028

-- ---------------- bottom centre: the vitals stack ----------------
-- The whole readout the player actually watches lives in one block, centred
-- between Roblox's thumbstick and its jump button:
--
--   [ ][ ][ ][ ][ ][ ]        hotbar, one square per toy
--   ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔          experience
--   120/120 ████████  HP
--     78/100 ██████   ENR
--   MENU     LEVEL 4   40/160
--
-- x 0.26-0.66 keeps it clear of the thumbstick (0-0.24) and leaves the
-- bottom-right corner to the action buttons and Roblox's jump.
Layout.VitalsX = 0.46 -- centre
Layout.VitalsBottom = 0.985
Layout.VitalsW = 0.40
Layout.VitalsH = 0.105

Layout.HotbarBottom = 0.872
Layout.HotbarW = 0.40
Layout.HotbarH = 0.068
Layout.HotbarGap = 0.012 -- of the row

-- ---------------- bottom right: the action cluster ----------------
-- Explicit positions rather than a row. A row of equal buttons gives the
-- thumb nothing to aim at; an arc with one big primary is what every action
-- game on a phone does, and it is reachable without looking.
-- Everything stays left of x = 0.79 so it never fights Roblox's jump button.
Layout.Actions = {
	Punch = { x = 0.745, y = 0.855, size = 0.130 },
	Sprint = { x = 0.745, y = 0.702, size = 0.098 },
	Toy = { x = 0.641, y = 0.700, size = 0.098 },
}

Layout.ReticleY = 0.42
Layout.ReticleH = 0.05

Layout.Order = {
	Sprint = 10,
	Punch = 20,
	Toy = 30,
}

-- A square whose side is `fraction` of the parent's HEIGHT.
--
-- fromScale(1, f) makes the bounding box the full parent width by f of its
-- height; FitWithinMaxSize then fits the largest 1:1 square inside that, which
-- is f of the height. Never pass 0 as the width.
function Layout.Square(object: GuiObject, fraction: number)
	object.Size = UDim2.fromScale(1, fraction)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = object
end

-- Text fills its box, with a ceiling so a desktop does not get a poster.
function Layout.FitText(label: GuiObject, maxSize: number?)
	(label :: any).TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize or 26
	constraint.MinTextSize = 7
	constraint.Parent = label
end

-- One action button, placed at its own spot in the bottom-right cluster.
function Layout.ActionSlot(button: GuiObject, name: string, gui: Instance)
	local slot = Layout.Actions[name]
	if not slot then
		error("no action slot named " .. name)
	end
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(slot.x, slot.y)
	button.ZIndex = 30
	Layout.Square(button, slot.size)
	button.Parent = gui
end

-- The hotbar: a centred row of squares sitting on top of the vitals block.
function Layout.Hotbar(gui: Instance): Frame
	local existing = gui:FindFirstChild("Hotbar")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local row = Instance.new("Frame")
	row.Name = "Hotbar"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.fromScale(Layout.VitalsX, Layout.HotbarBottom)
	row.Size = UDim2.fromScale(Layout.HotbarW, Layout.HotbarH)
	row.BackgroundTransparency = 1
	row.ZIndex = 28
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(Layout.HotbarGap, 0)
	list.Parent = row
	return row
end

-- Kept only for the modal panels, which are centred and sized in scale too.
function Layout.px(n: number): number
	return math.max(1, math.floor(n * 0.5))
end

function Layout.Attach(_gui: ScreenGui) end
function Layout.Init() end

return Layout
