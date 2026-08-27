--!strict
-- The HUD, laid out the way the big Roblox social games lay theirs out.
--
-- The middle of the screen belongs to the player and the world. Status is a
-- row of small pills along the top. Menus are a rail of square icons on the
-- right edge, collapsible, with a MORE tile that opens the rest. Nothing sits
-- where you are trying to look.
--
-- Every size comes from Layout, which measures the real viewport — the old
-- version guessed at a reference height and put a card across the player's
-- face on a phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local HudController = {}

local player = Players.LocalPlayer

-- Everything behind the MENU chip in the vitals block.
local MORE = {
	{ label = "REP", panel = "Rep", icon = "⭐", color = Palette.BusYellow },
	{ label = "GRADES", panel = "Rebirth", icon = "🎓", color = Palette.LockerBlue },
	{ label = "REWARDS", panel = "Rewards", icon = "🎁", color = Palette.BusYellow },
	{ label = "CLIQUES", panel = "Cliques", icon = "🏷️", color = Palette.DetentionRed },
	{ label = "TOP", panel = "Top", icon = "🏆", color = Palette.Chalk },
	{ label = "STORE", panel = "Store", icon = "🛒", color = Palette.CashGreen },
	{ label = "CREW", panel = "Crew", icon = "👥", color = Palette.AuraPurple },
	{ label = "QUESTS", panel = "Quests", icon = "📋", color = Palette.AuraPurple },
	{ label = "CLASSES", panel = "Classes", icon = "📕", color = Palette.LockerBlue },
}

-- one small top pill: an icon and a value, sized as a share of the pill row
local function pill(parent: Instance, order: number, accent: Color3): (TextLabel, Frame)
	local frame = UIBuilder.Frame({
		Size = UDim2.fromScale(Layout.PillW, 1),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.25,
		LayoutOrder = order,
		Parent = parent,
	})
	UIBuilder.Round(frame, 999)
	UIBuilder.Stroke(frame, accent, 2)
	local label = UIBuilder.Label({
		Position = UDim2.fromScale(0.06, 0.16),
		Size = UDim2.fromScale(0.88, 0.68),
		Text = "",
		Parent = frame,
	})
	Layout.FitText(label, 24)
	return label, frame
end

function HudController.Init(gui: ScreenGui)
	-- ---------------- top centre: the status pills ----------------
	local top = UIBuilder.Frame({
		Name = "StatusPills",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, Layout.PillsY),
		Size = UDim2.fromScale(Layout.PillsW, Layout.PillsH),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local topRow = Instance.new("UIListLayout")
	topRow.FillDirection = Enum.FillDirection.Horizontal
	topRow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topRow.VerticalAlignment = Enum.VerticalAlignment.Center
	topRow.SortOrder = Enum.SortOrder.LayoutOrder
	topRow.Padding = UDim.new(Layout.PillGap, 0)
	topRow.Parent = top

	local cashLabel = pill(top, 1, Palette.CashGreen)
	local auraLabel = pill(top, 2, Palette.AuraPurple)
	local periodLabel = pill(top, 3, Palette.BusYellow)
	local lockLabel, lockPill = pill(top, 4, Palette.DetentionRed)
	lockPill.Visible = false

	-- The left edge used to carry a rail of four round tiles. It is empty now:
	-- the reference layout the game is being matched to puts one MENU chip in
	-- the vitals block and nothing else along the sides, and every complaint
	-- about this HUD has been that there was too much of it. The panels are
	-- unchanged -- MENU opens the same grid the rail's ☰ tile opened.

	-- ---------------- the MORE hub ----------------
	local _, menuContent = UIBuilder.Panel(gui, "Menu", "MENU")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.31, 0.29)
	grid.CellPadding = UDim2.fromScale(0.02, 0.03)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = menuContent
	for i, item in MORE do
		local tile = UIBuilder.Button({
			Text = "",
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.1,
			LayoutOrder = i,
		}, function()
			UIBuilder.Toggle(item.panel)
		end)
		UIBuilder.Round(tile, 10)
		UIBuilder.Stroke(tile, item.color, 2)
		tile.Parent = menuContent
		UIBuilder.Label({
			Position = UDim2.fromScale(0, 0.08),
			Size = UDim2.new(1, 0, 0.46, 0),
			Text = item.icon,
			Parent = tile,
		})
		UIBuilder.Label({
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.new(1, 0, 0.32, 0),
			Text = item.label,
			TextColor3 = item.color,
			Parent = tile,
		})
	end
	local stamp = UIBuilder.Label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromScale(0.6, 0.06),
		Text = "",
		TextColor3 = Color3.fromRGB(140, 150, 140),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = menuContent,
	})
	task.spawn(function()
		while stamp.Parent do
			local grade = player:GetAttribute("Grade")
			stamp.Text = ("%s · build %d · %s"):format(
				Rebirths.GradeName(typeof(grade) == "number" and grade or 0),
				game.PlaceVersion,
				player:GetAttribute("DataLoaded") == true and "saved" or "saving…"
			)
			task.wait(3)
		end
	end)

	-- ---------------- live values ----------------
	local shownCash = 0
	local textClock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local cash = player:GetAttribute("Cash")
		local realCash = typeof(cash) == "number" and cash or 0
		if math.abs(realCash - shownCash) < 1 then
			shownCash = realCash
		else
			shownCash += (realCash - shownCash) * math.min(dt * 8, 1)
		end
		cashLabel.Text = "$" .. NumberFormat.Abbreviate(shownCash)

		textClock += dt
		if textClock < 0.2 then
			return
		end
		textClock = 0

		local aura = player:GetAttribute("Aura")
		local grade = player:GetAttribute("Grade")
		local gradeNum = typeof(grade) == "number" and grade or 0
		auraLabel.Text = ("%s ⚡ x%.1f"):format(
			NumberFormat.Abbreviate(typeof(aura) == "number" and aura or 0),
			Rebirths.Multiplier(gradeNum)
		)

		local period = ReplicatedStorage:GetAttribute("Period")
		local periodEnds = ReplicatedStorage:GetAttribute("PeriodEndsAt")
		if typeof(period) == "string" and typeof(periodEnds) == "number" then
			periodLabel.Text = period .. " " .. NumberFormat.Clock(periodEnds - workspace:GetServerTimeNow())
		else
			periodLabel.Text = "School's in"
		end

		local lockUntil = player:GetAttribute("LockUntil")
		if typeof(lockUntil) == "number" then
			local remaining = lockUntil - workspace:GetServerTimeNow()
			lockPill.Visible = remaining > 0
			if remaining > 0 then
				lockLabel.Text = "🔒 " .. NumberFormat.Clock(remaining)
			end
		end
	end)

	local _ = TweenService
end

return HudController
