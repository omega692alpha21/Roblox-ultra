--!strict
-- Cliques panel: the four clique cards with perks + join buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local CliqueController = {}

local player = Players.LocalPlayer

local PERK_TEXT: { [string]: string } = {
	jocks = "+2 walkspeed, harder punches",
	nerds = "+50% quiz rewards",
	preps = "+1h offline earnings cap",
	rebels = "carry stolen students faster",
}

function CliqueController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Cliques", "COURTYARD — PICK YOUR CLIQUE")
	local list = UIBuilder.List(content)

	local joinButtons: { [string]: TextButton } = {}
	for i, clique in Cliques.List do
		local frame = UIBuilder.Frame({
			Size = UDim2.new(1, -8, 0, 76),
			BackgroundColor3 = Palette.PanelBg,
			BackgroundTransparency = 0.3,
			LayoutOrder = i,
			Parent = list,
		})
		UIBuilder.Round(frame, 10)
		UIBuilder.Stroke(frame, clique.color, 2.5)
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -140, 0, 30),
			Text = clique.name,
			TextColor3 = clique.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -140, 0, 16),
			Text = PERK_TEXT[clique.id] or "",
			TextColor3 = Palette.Chalk,
			TextScaled = false,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.new(1, -140, 0, 16),
			Text = clique.motto,
			TextColor3 = Color3.fromRGB(157, 183, 154),
			TextScaled = false,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local join = UIBuilder.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 44),
			Text = "JOIN",
			BackgroundColor3 = clique.color,
		}, function()
			Remotes.Get("JoinClique"):FireServer(clique.id)
		end)
		UIBuilder.Round(join, 999)
		join.Parent = frame
		joinButtons[clique.id] = join
	end

	UIBuilder.Label({
		Position = UDim2.new(0, 0, 1, -24),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "First join is free. Switching costs 10% of your cash.",
		TextColor3 = Palette.BusYellow,
		TextScaled = false,
		TextSize = 14,
		Parent = content,
	})

	local function refresh()
		local mine = player:GetAttribute("Clique")
		for id, button in joinButtons do
			if mine == id then
				button.Text = "YOURS"
			else
				button.Text = "JOIN"
			end
		end
	end
	player:GetAttributeChangedSignal("Clique"):Connect(refresh)
	refresh()
end

return CliqueController
