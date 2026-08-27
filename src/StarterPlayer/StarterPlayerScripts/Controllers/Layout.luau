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

-- ---------------- left band ----------------
Layout.MinimapY = 0.15
Layout.MinimapH = 0.17 -- square, so 0.17 of height

Layout.MenuRailY = 0.35
Layout.MenuRailW = 0.30 -- a generous max width; the squares are much narrower
Layout.MenuRailH = 0.34
Layout.MenuTiles = 4
Layout.MenuTileH = 0.22 -- of the rail => 0.075 of the screen
Layout.MenuTileGap = 0.04 -- of the rail

-- ---------------- right band ----------------
Layout.ToolRailY = 0.18
Layout.ToolRailW = 0.30
Layout.ToolRailH = 0.26
Layout.ToolTiles = 3
Layout.ToolTileH = 0.30 -- of the rail => 0.078 of the screen
Layout.ToolTileGap = 0.05 -- of the rail

-- ---------------- bottom centre ----------------
Layout.ActionRight = 0.78
Layout.ActionBottom = 0.96
Layout.ActionW = 0.34
Layout.ActionH = 0.115
Layout.ActionGap = 0.04 -- of the action row

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

-- The vertical rails: a scale-sized column of square tiles pinned to an edge.
function Layout.Rail(gui: Instance, name: string, side: string): Frame
	local existing = gui:FindFirstChild(name)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local left = side == "left"
	local rail = Instance.new("Frame")
	rail.Name = name
	rail.AnchorPoint = Vector2.new(left and 0 or 1, 0)
	rail.Position = UDim2.fromScale(left and Layout.EdgeX or 1 - Layout.EdgeX, left and Layout.MenuRailY or Layout.ToolRailY)
	rail.Size = UDim2.fromScale(
		left and Layout.MenuRailW or Layout.ToolRailW,
		left and Layout.MenuRailH or Layout.ToolRailH
	)
	rail.BackgroundTransparency = 1
	rail.ZIndex = 28
	rail.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(left and Layout.MenuTileGap or Layout.ToolTileGap, 0)
	list.HorizontalAlignment = left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rail
	return rail
end

-- The thumb row: bottom centre-right, clear of the jump control.
function Layout.ActionBar(gui: ScreenGui): Frame
	local existing = gui:FindFirstChild("ActionBar")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local row = Instance.new("Frame")
	row.Name = "ActionBar"
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.fromScale(Layout.ActionRight, Layout.ActionBottom)
	row.Size = UDim2.fromScale(Layout.ActionW, Layout.ActionH)
	row.BackgroundTransparency = 1
	row.ZIndex = 30
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(Layout.ActionGap, 0)
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
