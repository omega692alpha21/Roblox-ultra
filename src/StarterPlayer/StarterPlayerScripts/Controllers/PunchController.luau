--!strict
-- Punch input: F key / mobile button, with a client-side cooldown mirror
-- (the server enforces the real one).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local PunchController = {}

local lastPunch = 0

local function punch()
	local now = os.clock()
	if now - lastPunch < GameConfig.PunchCooldownSeconds then
		return
	end
	lastPunch = now
	Remotes.Get("Punch"):FireServer()
end

function PunchController.Init(gui: ScreenGui)
	ContextActionService:BindAction("Punch", function(_, state)
		if state == Enum.UserInputState.Begin then
			punch()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	if UserInputService.TouchEnabled then
		local button = UIBuilder.Button({
			Name = "PunchButton",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -110),
			Size = UDim2.fromOffset(92, 92),
			Text = "PUNCH",
			BackgroundColor3 = Palette.DetentionRed,
			BackgroundTransparency = 0.15,
		}, punch)
		UIBuilder.Round(button, 999)
		UIBuilder.Stroke(button, Palette.White, 3)
		button.Parent = gui
	else
		UIBuilder.Label({
			Name = "PunchHint",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -12),
			Size = UDim2.fromOffset(220, 24),
			Text = "F — punch (catch thieves!)",
			TextColor3 = Palette.Chalk,
			TextScaled = false,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = gui,
		})
	end
end

return PunchController
