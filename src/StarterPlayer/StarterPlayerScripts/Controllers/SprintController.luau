--!strict
-- Sprint: hold Shift (desktop) or toggle the mobile button. The server owns the
-- actual speed; the client adds the feel — an FOV kick while sprinting.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local SprintController = {}

local sprinting = false
local baseFov = 70

local function setSprint(on: boolean)
	if sprinting == on then
		return
	end
	sprinting = on
	Remotes.Get("Sprint"):FireServer(on)
	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(
			camera,
			TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ FieldOfView = on and baseFov + 9 or baseFov }
		):Play()
	end
end

function SprintController.Init(gui: ScreenGui)
	local camera = workspace.CurrentCamera
	if camera then
		baseFov = camera.FieldOfView
	end

	ContextActionService:BindAction("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			setSprint(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	if UserInputService.TouchEnabled then
		local button = UIBuilder.Button({
			Name = "SprintButton",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -214),
			Size = UDim2.fromOffset(76, 76),
			Text = "RUN",
			BackgroundColor3 = Palette.LockerBlue,
			BackgroundTransparency = 0.15,
		}, function()
			setSprint(not sprinting)
		end)
		UIBuilder.Round(button, 999)
		UIBuilder.Stroke(button, Palette.White, 3)
		button.Parent = gui
	end
end

return SprintController
