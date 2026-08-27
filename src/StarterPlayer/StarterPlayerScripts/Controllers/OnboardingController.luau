--!strict
-- First day: a marker in the world on the thing you are supposed to walk to.
--
-- The goal bar already says what the step is. What a new player is actually
-- missing is *where*, so this puts a floating beacon on the target with a live
-- distance — in the world, where they are already looking, rather than as one
-- more card stacked on top of the screen. It is built client-side off
-- replicated attributes, so it costs the server nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)

local OnboardingController = {}

local player = Players.LocalPlayer

function OnboardingController.Init(gui: ScreenGui)
	-- ---- the beacon, local to this client ----
	local beacon = Instance.new("Part")
	beacon.Name = "TutorialBeacon"
	beacon.Size = Vector3.new(3, 3, 3)
	beacon.Transparency = 1
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BeaconTag"
	billboard.Size = UDim2.fromOffset(150, 62)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.Parent = beacon

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(1, 0, 0, 34)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = Palette.CashGreen
	arrow.TextStrokeTransparency = 0.3
	arrow.Parent = billboard

	local distance = Instance.new("TextLabel")
	distance.Position = UDim2.fromOffset(0, 34)
	distance.Size = UDim2.new(1, 0, 0, 24)
	distance.BackgroundTransparency = 1
	distance.Font = Enum.Font.FredokaOne
	distance.TextScaled = true
	distance.TextColor3 = Color3.fromRGB(255, 250, 235)
	distance.TextStrokeTransparency = 0.4
	distance.Text = ""
	distance.Parent = billboard

	local bob = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local target = player:GetAttribute("TutorialTarget")
		if typeof(target) ~= "Vector3" then
			billboard.Enabled = false
			return
		end
		billboard.Enabled = true
		bob += dt * 3
		beacon.Position = target + Vector3.new(0, 4 + math.sin(bob) * 0.6, 0)

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		distance.Text = if root then ("%d studs"):format(math.floor((root.Position - target).Magnitude)) else ""
	end)
end

return OnboardingController
