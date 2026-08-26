--!strict
-- Dialogue box for mission characters: speaker name, one line at a time, tap to advance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local DialogueController = {}

function DialogueController.Init(gui: ScreenGui)
	local box = UIBuilder.Frame({
		Name = "DialogueBox",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(560, 150),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.03,
		Visible = false,
		Parent = gui,
	})
	UIBuilder.Round(box, 16)
	UIBuilder.Stroke(box, Palette.BusYellow, 3)

	local speakerChip = UIBuilder.Frame({
		Position = UDim2.fromOffset(16, -16),
		Size = UDim2.fromOffset(220, 34),
		BackgroundColor3 = Palette.BusYellow,
		Parent = box,
	})
	UIBuilder.Round(speakerChip, 10)
	local speakerLabel = UIBuilder.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = Palette.Blackboard,
		Parent = speakerChip,
	})

	local textLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(18, 28),
		Size = UDim2.new(1, -36, 1, -70),
		Text = "",
		TextWrapped = true,
		TextScaled = false,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = box,
	})

	local lines: { string } = {}
	local index = 0

	local nextButton: TextButton
	nextButton = UIBuilder.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(130, 36),
		Text = "CONTINUE",
		BackgroundColor3 = Palette.CashGreen,
	}, function()
		index += 1
		if index > #lines then
			box.Visible = false
			return
		end
		textLabel.Text = lines[index]
		nextButton.Text = index >= #lines and "CLOSE" or "CONTINUE"
	end)
	UIBuilder.Round(nextButton, 10)
	nextButton.Parent = box

	Remotes.Get("Dialogue").OnClientEvent:Connect(function(speaker, incoming)
		if typeof(speaker) ~= "string" or typeof(incoming) ~= "table" or #incoming == 0 then
			return
		end
		lines = incoming :: any
		index = 1
		speakerLabel.Text = speaker
		textLabel.Text = lines[1]
		nextButton.Text = #lines <= 1 and "CLOSE" or "CONTINUE"
		box.Visible = true
	end)
end

return DialogueController
