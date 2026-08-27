--!strict
-- Sprint: hold Shift (desktop) or toggle the mobile button. The server owns the
-- actual speed; the client adds the feel — an FOV kick while sprinting.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
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

	-- Apply it here too. The server is still authoritative — it recomputes the
	-- real speed a moment later and lands on this same number — but waiting a
	-- full round trip to start moving faster is exactly what makes a sprint
	-- button feel dead.
	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.WalkSpeed > 0 then
		humanoid.WalkSpeed = math.max(1, humanoid.WalkSpeed + (on and GameConfig.SprintBonus or -GameConfig.SprintBonus))
	end

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
			Size = UDim2.new(0, 0, Layout.ButtonScale, 0),
			Text = "🏃",
			BackgroundColor3 = Palette.LockerBlue,
			BackgroundTransparency = 0.15,
			LayoutOrder = Layout.Order.Sprint,
		}, function()
			setSprint(not sprinting)
		end)
		Layout.Ratio(button, 1)
		Layout.FitText(button, 0.062)
		UIBuilder.Round(button, 999)
		UIBuilder.Stroke(button, Palette.White, 3)
		button.Parent = Layout.ActionBar(gui)
	end
end

return SprintController
