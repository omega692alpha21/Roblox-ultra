--!strict
-- Punch input: F key / mobile button, with a client-side cooldown mirror
-- (the server enforces the real one).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
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
		-- shares the one bottom-right action bar; no more hand-placed offsets
		-- colliding with RUN and THROW
		local button = UIBuilder.Button({
			Name = "PunchButton",
			Size = UDim2.fromOffset(76, 76),
			Text = "PUNCH",
			TextScaled = false,
			TextSize = 20,
			BackgroundColor3 = Palette.DetentionRed,
			BackgroundTransparency = 0.15,
			LayoutOrder = Layout.Order.Punch,
		}, punch)
		UIBuilder.Round(button, 999)
		UIBuilder.Stroke(button, Palette.White, 3)
		button.Parent = Layout.ActionBar(gui)
	end
end

return PunchController
