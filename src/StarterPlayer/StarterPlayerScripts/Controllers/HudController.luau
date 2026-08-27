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

-- one line of the status strip: a value on the left, a smaller note on the right
local function statLine(parent: Instance, order: number, color: Color3, size: number): (TextLabel, TextLabel)
	local row = UIBuilder.Frame({
		Size = UDim2.new(1, 0, 0, Layout.px(size + 4)),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	local key = UIBuilder.Label({
		Size = UDim2.new(0.55, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = Layout.px(size),
		Text = "",
		Parent = row,
	})
	local value = UIBuilder.Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = false,
		TextSize = Layout.px(size - 3),
		TextColor3 = color,
		Text = "",
		Parent = row,
	})
	return key, value
end

function HudController.Init(gui: ScreenGui)
	-- ---- the status strip: thin, top-aligned, out of the player's face ----
	local card = UIBuilder.Frame({
		Name = "StatusCard",
		Position = UDim2.fromOffset(Layout.StatusX, Layout.Margin),
		Size = UDim2.fromOffset(Layout.px(196), Layout.px(78)),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	UIBuilder.Round(card, Layout.px(10))
	UIBuilder.Stroke(card, Palette.LockerBlue, 2)

	local inner = UIBuilder.Frame({
		Position = UDim2.fromOffset(Layout.px(10), Layout.px(6)),
		Size = UDim2.new(1, -Layout.px(20), 1, -Layout.px(12)),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local rows = Instance.new("UIListLayout")
	rows.Padding = UDim.new(0, Layout.px(1))
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Parent = inner

	local cashKey, cashValue = statLine(inner, 1, Palette.CashGreen, 22)
	local auraKey, auraValue = statLine(inner, 2, Palette.AuraPurple, 18)
	local periodKey, periodValue = statLine(inner, 3, Palette.BusYellow, 15)

	-- ---- lock chip, top right, only while the base is locked ----
	local lockFrame = UIBuilder.Frame({
		Name = "LockTimer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Layout.Margin, 0, Layout.Margin),
		Size = UDim2.fromOffset(Layout.px(158), Layout.px(34)),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	UIBuilder.Round(lockFrame, Layout.px(10))
	UIBuilder.Stroke(lockFrame, Palette.DetentionRed, 3)
	local lockLabel = UIBuilder.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "BASE LOCKED 0:00",
		TextScaled = false,
		TextSize = Layout.px(18),
		TextColor3 = Color3.fromRGB(255, 157, 143),
		Parent = lockFrame,
	})

	-- ---- the menu hub: one panel that reaches every other panel ----
	local _, menuContent = UIBuilder.Panel(gui, "Menu", "MENU")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(Layout.px(150), Layout.px(92))
	grid.CellPadding = UDim2.fromOffset(Layout.px(10), Layout.px(10))
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
			Position = UDim2.fromOffset(0, Layout.px(10)),
			Size = UDim2.new(1, 0, 0, Layout.px(38)),
			Text = item.icon,
			Parent = tile,
		})
		UIBuilder.Label({
			Position = UDim2.new(0, 0, 1, -Layout.px(34)),
			Size = UDim2.new(1, 0, 0, Layout.px(26)),
			Text = item.label,
			TextColor3 = item.color,
			TextScaled = false,
			TextSize = Layout.px(18),
			Parent = tile,
		})
	end
	-- build number and save state live here now instead of being stamped over
	-- the game in three different corners
	local stamp = UIBuilder.Label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(Layout.px(280), Layout.px(18)),
		Text = "",
		TextColor3 = Color3.fromRGB(140, 150, 140),
		TextScaled = false,
		TextSize = Layout.px(14),
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

	-- ---- the single MENU button, bottom left ----
	local menuButton = UIBuilder.Button({
		Name = "MenuButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, Layout.Margin, 1, -Layout.Margin),
		Size = UDim2.fromOffset(Layout.px(104), Layout.px(44)),
		Text = "☰  MENU",
		TextScaled = false,
		TextSize = Layout.px(21),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.1,
	}, function()
		UIBuilder.Toggle("Menu")
	end)
	UIBuilder.Round(menuButton, 999)
	UIBuilder.Stroke(menuButton, Palette.BusYellow, 3)
	menuButton.Parent = gui

	-- Live updates. The cash counter animates every frame because that motion
	-- is the reward feedback; everything else is text that only has to be
	-- correct, so it refreshes eight times a second instead of sixty.
	local shownCash = 0
	local textClock = 0
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

		textClock += dt
		if textClock < 0.125 then
			return
		end
		textClock = 0
		cashValue.Text = "+" .. NumberFormat.Abbreviate(typeof(income) == "number" and income or 0) .. "/s"

		local aura = player:GetAttribute("Aura")
		local rank = player:GetAttribute("Rank")
		auraKey.Text = NumberFormat.Abbreviate(typeof(aura) == "number" and aura or 0) .. " aura"
		auraValue.Text = typeof(rank) == "string" and rank or "NPC"

		-- grade name lives in MENU now; only the multiplier is worth the space
		local grade = player:GetAttribute("Grade")
		local gradeNum = typeof(grade) == "number" and grade or 0
		periodValue.Text = ("x%.1f"):format(Rebirths.Multiplier(gradeNum))

		local period = ReplicatedStorage:GetAttribute("Period")
		local periodEnds = ReplicatedStorage:GetAttribute("PeriodEndsAt")
		if typeof(period) == "string" and typeof(periodEnds) == "number" then
			periodKey.Text = period:upper() .. " " .. NumberFormat.Clock(periodEnds - workspace:GetServerTimeNow())
		else
			periodKey.Text = "SCHOOL'S IN"
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
