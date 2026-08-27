--!strict
-- First-join starter pick: THE TROUBLEMAKER or THE REBEL. Shown once (choice
-- persists in the profile); the server dresses the avatar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local CharacterSelectController = {}

local player = Players.LocalPlayer

local CARDS = {
	{
		id = "boy",
		title = "THE TROUBLEMAKER",
		line = "Navy crest sweater. Bandage. Backpack.\nRules are suggestions.",
		accent = Color3.fromRGB(38, 50, 96),
		emoji = "😠",
	},
	{
		id = "girl",
		title = "THE REBEL",
		line = "Plaid skirt. Bubblegum. Zero patience.\nDetention regular.",
		accent = Color3.fromRGB(120, 82, 168),
		emoji = "🫧",
	},
}

local function show(gui: ScreenGui)
	local overlay = UIBuilder.Frame({
		Name = "CharacterSelect",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 16, 26),
		BackgroundTransparency = 0.25,
		ZIndex = 40,
		Parent = gui,
	})
	UIBuilder.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.new(0, 520, 0, 44),
		Text = "CHOOSE YOUR STARTER",
		TextColor3 = Color3.fromRGB(255, 196, 60),
		ZIndex = 41,
		Parent = overlay,
	})
	for i, card in CARDS do
		local frame = UIBuilder.Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + (i - 1.5) * 0.24, 0.5),
			Size = UDim2.fromOffset(210, 250),
			BackgroundColor3 = Palette.PanelBg,
			ZIndex = 41,
			Parent = overlay,
		})
		UIBuilder.Round(frame, 16)
		UIBuilder.Stroke(frame, card.accent, 4)
		UIBuilder.Label({
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 64),
			Text = card.emoji,
			ZIndex = 42,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromOffset(8, 86),
			Size = UDim2.new(1, -16, 0, 30),
			Text = card.title,
			TextColor3 = Color3.fromRGB(255, 196, 60),
			ZIndex = 42,
			Parent = frame,
		})
		UIBuilder.Label({
			Position = UDim2.fromOffset(10, 122),
			Size = UDim2.new(1, -20, 0, 66),
			Text = card.line,
			TextColor3 = Palette.Chalk,
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			ZIndex = 42,
			Parent = frame,
		})
		local pick = UIBuilder.Button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.fromOffset(150, 42),
			Text = "PICK",
			BackgroundColor3 = card.accent,
			ZIndex = 42,
		}, function()
			Remotes.Get("ChooseCharacter"):FireServer(card.id)
			overlay:Destroy()
		end)
		UIBuilder.Round(pick, 999)
		pick.Parent = frame
	end
end

function CharacterSelectController.Init(gui: ScreenGui)
	task.spawn(function()
		-- wait for the profile, then only prompt players who never picked
		for _ = 1, 120 do
			if player:GetAttribute("DataLoaded") == true then
				break
			end
			task.wait(0.5)
		end
		task.wait(1)
		if player:GetAttribute("Outfit") == nil and player:GetAttribute("DataLoaded") == true then
			show(gui)
		end
	end)
end

return CharacterSelectController
