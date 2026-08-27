--!strict
-- HUD: cash + income, aura + rank, grade badge, lock timer, nav rail.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local UIBuilder = require(script.Parent.UIBuilder)

local HudController = {}

local player = Players.LocalPlayer

local function pill(parent: Instance, name: string, position: UDim2, color: Color3): (Frame, TextLabel, TextLabel)
	local frame = UIBuilder.Frame({
		Name = name,
		Position = position,
		Size = UDim2.fromOffset(190, 56),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.1,
		Parent = parent,
	})
	UIBuilder.Round(frame, 999)
	UIBuilder.Stroke(frame, color, 3)
	UIBuilder.Sheen(frame)
	local top = UIBuilder.Label({
		Name = "Top",
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(1, -24, 0, 27),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = frame,
	})
	local bottom = UIBuilder.Label({
		Name = "Bottom",
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -24, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Text = "",
		Parent = frame,
	})
	return frame, top, bottom
end

function HudController.Init(gui: ScreenGui)
	-- currency pills
	local _, cashTop, cashBottom = pill(gui, "CashPill", UDim2.fromOffset(12, 10), Palette.CashGreen)
	local _, auraTop, auraBottom = pill(gui, "AuraPill", UDim2.fromOffset(12, 74), Palette.AuraPurple)

	-- grade badge (top center)
	local gradeBadge = UIBuilder.Frame({
		Name = "GradeBadge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(260, 58),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	UIBuilder.Round(gradeBadge, 12)
	UIBuilder.Stroke(gradeBadge, Palette.LockerBlue, 3)
	local gradeLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 28),
		Text = "Freshman Year",
		Parent = gradeBadge,
	})
	local periodLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextColor3 = Palette.BusYellow,
		Parent = gradeBadge,
	})

	-- lock timer (top right)
	local lockFrame = UIBuilder.Frame({
		Name = "LockTimer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(190, 46),
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
		TextColor3 = Color3.fromRGB(255, 157, 143),
		Parent = lockFrame,
	})

	-- nav rail
	local nav = UIBuilder.Frame({
		Name = "NavRail",
		Position = UDim2.fromOffset(12, 150),
		Size = UDim2.fromOffset(84, 8 * 62),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 8)
	navLayout.Parent = nav
	local navItems = {
		{ label = "REP", panel = "Rep", color = Palette.BusYellow },
		{ label = "CREW", panel = "Crew", color = Palette.AuraPurple },
		{ label = "STORE", panel = "Store", color = Palette.CashGreen },
		{ label = "GRADES", panel = "Rebirth", color = Palette.LockerBlue },
		{ label = "REWARDS", panel = "Rewards", color = Palette.BusYellow },
		{ label = "QUESTS", panel = "Quests", color = Palette.AuraPurple },
		{ label = "CLIQUES", panel = "Cliques", color = Palette.DetentionRed },
		{ label = "TOP", panel = "Top", color = Palette.Chalk },
	}
	for i, item in navItems do
		local button = UIBuilder.Button({
			Size = UDim2.fromOffset(84, 54),
			Text = item.label,
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.1,
			LayoutOrder = i,
		}, function()
			UIBuilder.Toggle(item.panel)
		end)
		UIBuilder.Round(button, 12)
		UIBuilder.Stroke(button, item.color, 3)
		button.Parent = nav
	end

	-- build stamp so testers can confirm which version their server runs
	UIBuilder.Label({
		Name = "BuildStamp",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -4),
		Size = UDim2.fromOffset(120, 16),
		Text = "build " .. tostring(game.PlaceVersion),
		TextColor3 = Color3.fromRGB(160, 170, 160),
		TextScaled = false,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = gui,
	})

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
		cashTop.Text = "$" .. NumberFormat.Abbreviate(shownCash)
		cashBottom.Text = "+" .. NumberFormat.Abbreviate(typeof(income) == "number" and income or 0) .. "/s"

		local aura = player:GetAttribute("Aura")
		local rank = player:GetAttribute("Rank")
		auraTop.Text = NumberFormat.Abbreviate(typeof(aura) == "number" and aura or 0) .. " Aura"
		auraBottom.Text = typeof(rank) == "string" and rank or "NPC"

		local grade = player:GetAttribute("Grade")
		local gradeNum = typeof(grade) == "number" and grade or 0
		gradeLabel.Text = ("%s · x%.1f"):format(Rebirths.GradeName(gradeNum), Rebirths.Multiplier(gradeNum))

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
