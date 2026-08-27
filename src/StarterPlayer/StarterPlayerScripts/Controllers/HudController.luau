--!strict
-- The HUD: one status card beside the minimap, one lock chip top-right, and
-- one MENU button that opens every other screen.
--
-- There used to be two currency pills, a grade badge, a lock chip, an
-- eight-button nav rail and a build stamp all placed by hand. On a phone they
-- overlapped the minimap and each other, which is what "too much going on and
-- there is multiple menus" meant. Now there is exactly one always-on card and
-- one door into everything else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local HudController = {}

local player = Players.LocalPlayer

local MENU_ITEMS = {
	{ label = "REP", panel = "Rep", icon = "⭐", color = Palette.BusYellow },
	{ label = "CREW", panel = "Crew", icon = "👥", color = Palette.AuraPurple },
	{ label = "STORE", panel = "Store", icon = "🛒", color = Palette.CashGreen },
	{ label = "GRADES", panel = "Rebirth", icon = "🎓", color = Palette.LockerBlue },
	{ label = "REWARDS", panel = "Rewards", icon = "🎁", color = Palette.BusYellow },
	{ label = "QUESTS", panel = "Quests", icon = "📋", color = Palette.AuraPurple },
	{ label = "CLIQUES", panel = "Cliques", icon = "🏷️", color = Palette.DetentionRed },
	{ label = "TOP", panel = "Top", icon = "🏆", color = Palette.Chalk },
}

-- one line of the status card: a coloured key on the left, a value on the right
local function statLine(parent: Instance, order: number, color: Color3): (TextLabel, TextLabel)
	local row = UIBuilder.Frame({
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local key = UIBuilder.Label({
		Size = UDim2.new(0.52, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		Text = "",
		Parent = row,
	})
	local value = UIBuilder.Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.48, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = false,
		TextSize = 16,
		TextColor3 = color,
		Text = "",
		Parent = row,
	})
	return key, value
end

function HudController.Init(gui: ScreenGui)
	-- ---- the one status card, sitting beside the minimap ----
	local card = UIBuilder.Frame({
		Name = "StatusCard",
		Position = UDim2.fromOffset(Layout.StatusX, Layout.Margin),
		Size = UDim2.fromOffset(206, Layout.Minimap),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	UIBuilder.Round(card, 14)
	UIBuilder.Stroke(card, Palette.LockerBlue, 3)

	local inner = UIBuilder.Frame({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 1, -16),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, 2)
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Parent = inner

	local cashKey, cashValue = statLine(inner, 1, Palette.CashGreen)
	local auraKey, auraValue = statLine(inner, 2, Palette.AuraPurple)
	local gradeKey, gradeValue = statLine(inner, 3, Palette.BusYellow)
	local periodLabel = UIBuilder.Label({
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 4,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 15,
		TextColor3 = Palette.Chalk,
		Text = "",
		Parent = inner,
	})

	-- ---- lock chip, top right, only while the base is locked ----
	local lockFrame = UIBuilder.Frame({
		Name = "LockTimer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(168, 40),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	UIBuilder.Round(lockFrame, 12)
	UIBuilder.Stroke(lockFrame, Palette.DetentionRed, 3)
	local lockLabel = UIBuilder.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "BASE LOCKED 0:00",
		TextScaled = false,
		TextSize = 19,
		TextColor3 = Color3.fromRGB(255, 157, 143),
		Parent = lockFrame,
	})

	-- ---- the menu hub: one panel that reaches every other panel ----
	local _, menuContent = UIBuilder.Panel(gui, "Menu", "MENU")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 92)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = menuContent
	for i, item in MENU_ITEMS do
		local tile = UIBuilder.Button({
			Text = "",
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.1,
			LayoutOrder = i,
		}, function()
			-- Toggle closes every panel first, so the hub never stays behind
			UIBuilder.Toggle(item.panel)
		end)
		UIBuilder.Round(tile, 12)
		UIBuilder.Stroke(tile, item.color, 3)
		tile.Parent = menuContent
		UIBuilder.Label({
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 38),
			Text = item.icon,
			Parent = tile,
		})
		UIBuilder.Label({
			Position = UDim2.new(0, 0, 1, -34),
			Size = UDim2.new(1, 0, 0, 26),
			Text = item.label,
			TextColor3 = item.color,
			TextScaled = false,
			TextSize = 18,
			Parent = tile,
		})
	end
	-- build number and save state live here now instead of being stamped over
	-- the game in three different corners
	local stamp = UIBuilder.Label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(220, 18),
		Text = "",
		TextColor3 = Color3.fromRGB(140, 150, 140),
		TextScaled = false,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = menuContent,
	})
	task.spawn(function()
		while stamp.Parent do
			stamp.Text = ("build %d · %s"):format(
				game.PlaceVersion,
				player:GetAttribute("DataLoaded") == true and "saved" or "saving…"
			)
			task.wait(3)
		end
	end)

	-- ---- the single MENU button, bottom left ----
	local menuButton = UIBuilder.Button({
		Name = "MenuButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, Layout.Margin, 1, -Layout.Margin),
		Size = UDim2.fromOffset(112, 52),
		Text = "☰  MENU",
		TextScaled = false,
		TextSize = 22,
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.1,
	}, function()
		UIBuilder.Toggle("Menu")
	end)
	UIBuilder.Round(menuButton, 999)
	UIBuilder.Stroke(menuButton, Palette.BusYellow, 3)
	menuButton.Parent = gui

	-- live updates from attributes (cash animates toward the real value)
	local shownCash = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local cash = player:GetAttribute("Cash")
		local income = player:GetAttribute("Income")
		local realCash = typeof(cash) == "number" and cash or 0
		if math.abs(realCash - shownCash) < 1 then
			shownCash = realCash
		else
			shownCash += (realCash - shownCash) * math.min(dt * 8, 1)
		end
		cashKey.Text = "$" .. NumberFormat.Abbreviate(shownCash)
		cashValue.Text = "+" .. NumberFormat.Abbreviate(typeof(income) == "number" and income or 0) .. "/s"

		local aura = player:GetAttribute("Aura")
		local rank = player:GetAttribute("Rank")
		auraKey.Text = NumberFormat.Abbreviate(typeof(aura) == "number" and aura or 0) .. " aura"
		auraValue.Text = typeof(rank) == "string" and rank or "NPC"

		local grade = player:GetAttribute("Grade")
		local gradeNum = typeof(grade) == "number" and grade or 0
		gradeKey.Text = Rebirths.GradeName(gradeNum)
		gradeValue.Text = ("x%.1f"):format(Rebirths.Multiplier(gradeNum))

		local period = ReplicatedStorage:GetAttribute("Period")
		local periodEnds = ReplicatedStorage:GetAttribute("PeriodEndsAt")
		if typeof(period) == "string" and typeof(periodEnds) == "number" then
			periodLabel.Text = period:upper() .. " · " .. NumberFormat.Clock(periodEnds - workspace:GetServerTimeNow())
		else
			periodLabel.Text = "SCHOOL'S IN SESSION"
		end

		local lockUntil = player:GetAttribute("LockUntil")
		if typeof(lockUntil) == "number" then
			local remaining = lockUntil - workspace:GetServerTimeNow()
			if remaining > 0 then
				lockFrame.Visible = true
				lockLabel.Text = "BASE LOCKED " .. NumberFormat.Clock(remaining)
			else
				lockFrame.Visible = false
			end
		end
	end)
end

return HudController
