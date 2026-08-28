--!strict
-- Dialogue: speaker, one line at a time, and nothing else on screen.
--
-- It used to be a 560-pixel box parented to the HUD with no ZIndex at all, so
-- on a phone it sat behind the health bars, the hotbar and the action buttons
-- -- the CLOSE button was underneath the punch button. A character talking to
-- you is the most important thing on the screen for the four seconds they are
-- talking, so this is a modal in its own ScreenGui above everything, sized in
-- Scale like the rest of the HUD, and it swallows taps so nothing behind it
-- fires while you are reading.
--
-- The last press does not say CLOSE. It says ADD TO JOURNAL and opens it,
-- because a conversation that hands you three objectives and then vanishes has
-- told you nothing you can act on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local DialogueController = {}

function DialogueController.Init(_gui: ScreenGui)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "LMLDialogue"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 60 -- above the HUD (0) and the panels (20)
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = playerGui

	-- eats every tap that is not the button, so you cannot punch, throw or
	-- open a menu through the conversation
	local dim = Instance.new("TextButton")
	dim.Name = "Backdrop"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Modal = true
	dim.ZIndex = 300
	dim.Parent = screen

	local box = UIBuilder.Frame({
		Name = "DialogueBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.62, 0.34),
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.02,
		Parent = screen,
	})
	box.ZIndex = 310
	UIBuilder.Round(box, 18)
	UIBuilder.Stroke(box, Palette.BusYellow, 3)

	local speakerChip = UIBuilder.Frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.04, 0.02),
		Size = UDim2.fromScale(0.46, 0.2),
		BackgroundColor3 = Palette.BusYellow,
		Parent = box,
	})
	speakerChip.ZIndex = 312
	UIBuilder.Round(speakerChip, 12)
	local speakerLabel = UIBuilder.Label({
		Size = UDim2.fromScale(0.92, 0.7),
		Position = UDim2.fromScale(0.04, 0.15),
		Text = "",
		TextColor3 = Palette.Blackboard,
		Parent = speakerChip,
	})
	speakerLabel.ZIndex = 313
	Layout.FitText(speakerLabel, 26)

	local textLabel = UIBuilder.Label({
		Position = UDim2.fromScale(0.05, 0.16),
		Size = UDim2.fromScale(0.9, 0.52),
		Text = "",
		TextWrapped = true,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = box,
	})
	textLabel.ZIndex = 312
	Layout.FitText(textLabel, 24)

	local dots = UIBuilder.Label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.05, 0.95),
		Size = UDim2.fromScale(0.3, 0.13),
		Text = "",
		TextColor3 = Color3.fromRGB(150, 162, 178),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	dots.ZIndex = 312
	Layout.FitText(dots, 16)

	local lines: { string } = {}
	local index = 0

	local nextButton: TextButton
	local function show()
		textLabel.Text = lines[index] or ""
		dots.Text = ("%d / %d"):format(index, #lines)
		nextButton.Text = index >= #lines and "ADD TO JOURNAL" or "CONTINUE"
		-- a small rise on every line, so paging feels like paging
		box.Position = UDim2.fromScale(0.5, 0.575)
		TweenService:Create(box, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.56),
		}):Play()
	end

	nextButton = UIBuilder.Button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.96, 0.94),
		Size = UDim2.fromScale(0.4, 0.19),
		Text = "CONTINUE",
		BackgroundColor3 = Palette.CashGreen,
	}, function()
		if index >= #lines then
			screen.Enabled = false
			UIBuilder.Toggle("Journal")
			return
		end
		index += 1
		show()
	end)
	nextButton.ZIndex = 313
	UIBuilder.Round(nextButton, 999)
	Layout.FitText(nextButton, 22)
	nextButton.Parent = box

	Remotes.Get("Dialogue").OnClientEvent:Connect(function(speaker, incoming)
		if typeof(speaker) ~= "string" or typeof(incoming) ~= "table" or #incoming == 0 then
			return
		end
		lines = incoming :: any
		index = 1
		speakerLabel.Text = speaker
		screen.Enabled = true
		show()
	end)
end

return DialogueController
