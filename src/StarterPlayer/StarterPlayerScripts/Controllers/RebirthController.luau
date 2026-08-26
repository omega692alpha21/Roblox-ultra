--!strict
-- Grades panel: shows the next graduation cost + what you get, fires DoRebirth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local RebirthController = {}

local player = Players.LocalPlayer

function RebirthController.Init(gui: ScreenGui)
	local panel, content = UIBuilder.Panel(gui, "Rebirth", "GRADUATE — NEXT GRADE YEAR")

	local infoLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 60),
		Text = "",
		TextColor3 = Palette.Chalk,
		Parent = content,
	})
	local costLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 50),
		Text = "",
		TextColor3 = Palette.BusYellow,
		Parent = content,
	})
	local perksLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 90),
		Text = "You get:\n· permanent income multiplier\n· +1 desk slot\n· +10s lock duration\n\nYou lose: all cash and your whole crew!",
		TextColor3 = Palette.Chalk,
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		Parent = content,
	})
	local _ = perksLabel

	local button = UIBuilder.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(240, 54),
		Text = "GRADUATE",
		BackgroundColor3 = Palette.LockerBlue,
	}, function()
		Remotes.Get("DoRebirth"):FireServer()
	end)
	UIBuilder.Round(button, 14)
	button.Parent = content

	RunService.Heartbeat:Connect(function()
		if not panel.Visible then
			return
		end
		local grade = player:GetAttribute("Grade")
		local gradeNum = typeof(grade) == "number" and grade or 0
		local cash = player:GetAttribute("Cash")
		local cashNum = typeof(cash) == "number" and cash or 0
		local cost = Rebirths.CostFor(gradeNum + 1)
		infoLabel.Text = ("%s  →  %s\nIncome x%.1f  →  x%.1f"):format(
			Rebirths.GradeName(gradeNum),
			Rebirths.GradeName(gradeNum + 1),
			Rebirths.Multiplier(gradeNum),
			Rebirths.Multiplier(gradeNum + 1)
		)
		costLabel.Text = "Cost: $" .. NumberFormat.Abbreviate(cost)
		button.BackgroundColor3 = cashNum >= cost and Palette.CashGreen or Palette.LockerBlue
	end)
end

return RebirthController
