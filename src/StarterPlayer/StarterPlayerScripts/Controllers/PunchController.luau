--!strict
-- Punch input: F key / mobile button, with a client-side cooldown mirror
-- (the server enforces the real one).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActionPoses = require(ReplicatedStorage.Shared.ActionPoses)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local PunchController = {}

local lastPunch = 0
local comboStep = 0
-- must match FightService's chain
local COMBO_WINDOW = 1.15
local CHAIN = { "punch", "cross", "kick" }

local function punch()
	local now = os.clock()
	if now - lastPunch < GameConfig.PunchCooldownSeconds then
		return
	end
	-- Which beat of the chain this is. The same rule the server runs, so the
	-- pose that plays here is the pose that lands there.
	local step = if now - lastPunch <= COMBO_WINDOW then comboStep % #CHAIN + 1 else 1
	comboStep = step
	lastPunch = now
	-- Swing here and now rather than waiting for the server to tell us we
	-- swung: a round trip is a fifth of a second on a phone, which is longer
	-- than the punch, so the animation used to land after the hit.
	local character = Players.LocalPlayer.Character
	if character then
		ActionPoses.Play(character, CHAIN[step])
	end
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
		-- the primary action: the biggest circle, nearest the thumb
		local button = UIBuilder.Button({
			Name = "PunchButton",
			Text = "👊",
			BackgroundColor3 = Palette.DetentionRed,
			BackgroundTransparency = 0.15,
			LayoutOrder = Layout.Order.Punch,
		}, punch)
		Layout.FitText(button, 38)
		UIBuilder.Round(button, 999)
		UIBuilder.Stroke(button, Palette.White, 3)
		Layout.ActionSlot(button, "Punch", gui)
	end
end

return PunchController
