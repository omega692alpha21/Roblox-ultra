--!strict
-- Roles panel: what each role is good at, and a button to re-sort into it.
--
-- The perk lines used to be a hand-written table that drifted from the config
-- the moment a number changed. They are generated from the role's own stats
-- now, so the panel cannot lie about what the server will do.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Cliques = require(ReplicatedStorage.Config.Cliques)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local CliqueController = {}

local player = Players.LocalPlayer

-- Read the role's numbers and say only what is actually different about it.
local function perkLine(role): string
	local notes: { string } = {}
	local function pct(value: number): string
		return ("%+d%%"):format(math.floor((value - 1) * 100 + 0.5))
	end
	if role.maxHealth ~= 100 then
		table.insert(notes, ("%d health"):format(role.maxHealth))
	end
	if role.walkSpeedBonus ~= 0 then
		table.insert(notes, ("%+d speed"):format(role.walkSpeedBonus))
	end
	if role.damageMult ~= 1 then
		table.insert(notes, pct(role.damageMult) .. " damage")
	end
	if role.energyDrainMult ~= 1 then
		table.insert(notes, pct(2 - role.energyDrainMult) .. " stamina")
	end
	if role.aimAssistMult ~= 1 then
		table.insert(notes, pct(role.aimAssistMult) .. " aim")
	end
	if role.quizRewardMult ~= 1 then
		table.insert(notes, pct(role.quizRewardMult) .. " class pay")
	end
	if role.cashMult ~= 1 then
		table.insert(notes, pct(role.cashMult) .. " all cash")
	end
	if role.classTimeBonus ~= 0 then
		table.insert(notes, ("%+ds in class"):format(role.classTimeBonus))
	end
	return table.concat(notes, " · ")
end

function CliqueController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Cliques", "ROLES — RE-SORT AT THE COURTYARD BOARD")
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
			Text = clique.icon .. "  " .. clique.name,
			TextColor3 = clique.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -140, 0, 16),
			Text = perkLine(clique),
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
