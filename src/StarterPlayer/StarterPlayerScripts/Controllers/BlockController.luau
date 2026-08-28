--!strict
-- The guard: held, not toggled.
--
-- Held is the whole point. A toggle is a state you sit in and forget about; a
-- hold is a decision you keep making, and it costs energy the entire time, so
-- the interesting question is when to let go.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActionPoses = require(ReplicatedStorage.Shared.ActionPoses)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local player = Players.LocalPlayer

local BlockController = {}

local guarding = false

local function setGuard(down: boolean)
	if guarding == down then
		return
	end
	guarding = down
	local character = player.Character
	if character then
		if down then
			ActionPoses.Play(character, "block")
		else
			ActionPoses.Stop(character, "block")
		end
	end
	Remotes.Get("Block"):FireServer(down)
end

function BlockController.Init(gui: ScreenGui)
	ContextActionService:BindAction("Block", function(_, state)
		if state == Enum.UserInputState.Begin then
			setGuard(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setGuard(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonL2)

	if UserInputService.TouchEnabled then
		local button = UIBuilder.Button({
			Name = "BlockButton",
			Text = "🛡️",
			BackgroundColor3 = Palette.LockerBlue,
			BackgroundTransparency = 0.15,
			LayoutOrder = Layout.Order.Block,
			AutoButtonColor = false,
		}, function() end)
		Layout.FitText(button, 34)
		UIBuilder.Round(button, 999)
		local ring = UIBuilder.Stroke(button, Palette.White, 3)
		Layout.ActionSlot(button, "Block", gui)
		-- a hold, so press and release rather than Activated
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1 then
				setGuard(true)
				ring.Color = Palette.BusYellow
			end
		end)
		local function up()
			if guarding then
				setGuard(false)
				ring.Color = Palette.White
			end
		end
		button.InputEnded:Connect(up)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1 then
				up()
			end
		end)
	end

	-- never left guarding through a respawn
	player.CharacterAdded:Connect(function()
		if guarding then
			setGuard(false)
		end
	end)
end

return BlockController
