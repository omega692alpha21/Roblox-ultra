--!strict
-- Aiming.
--
-- Throwing used to send the camera's look direction to the server, which then
-- launched the projectile from the player's chest along that vector. With a
-- follow camera looking down at the avatar, that vector points at the ground
-- in front of them — which is why toys went everywhere except where you were
-- looking. There was also nothing on screen saying what you were aiming at.
--
-- This owns both halves: a reticle you aim with, and the world point under it
-- that the server solves a real trajectory to.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Layout = require(script.Parent.Layout)

local AimController = {}

local player = Players.LocalPlayer

-- The reticle sits above centre so it clears the avatar's head on a follow
-- camera. The aim ray is cast through this exact point, so what you see is
-- what you hit.
local RETICLE_Y = 0.42 -- kept in step with Layout.ReticleY for the aim ray
local MAX_RANGE = 400
-- how far off the reticle a target can snap to it, as a fraction of screen height
local ASSIST_FRACTION = 0.06
local ASSIST_RANGE = 220

local reticle: Frame? = nil
local aimPoint: Vector3? = nil
local enabled = false

-- Both of these walk the whole workspace, which on this campus is thousands of
-- instances. They refresh on a slow timer instead of every frame; the reticle
-- itself still updates at full rate off the cached lists.
local ignoreList: { Instance } = {}
local targets: { BasePart } = {}

local function refreshIgnore()
	local ignore: { Instance } = {}
	local character = player.Character
	if character then
		table.insert(ignore, character)
	end
	for _, item in workspace:GetChildren() do
		if item.Name == "ToyProjectile" then
			table.insert(ignore, item)
		end
	end
	ignoreList = ignore
end

-- every humanoid worth snapping to: other players and the campus students
local function refreshTargets()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		targets = {}
		return
	end
	local from = root.Position
	local out: { BasePart } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") and (otherRoot.Position - from).Magnitude < ASSIST_RANGE then
				table.insert(out, otherRoot)
			end
		end
	end
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and model ~= character and model:FindFirstChildOfClass("Humanoid") then
			local modelRoot = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if modelRoot and modelRoot:IsA("BasePart") and (modelRoot.Position - from).Magnitude < ASSIST_RANGE then
				table.insert(out, modelRoot)
			end
		end
	end
	targets = out
end

-- The world point the player is aiming at, and the target it snapped to.
function AimController.Point(): Vector3?
	return aimPoint
end

function AimController.SetEnabled(on: boolean)
	enabled = on
	local frame = reticle
	if frame then
		frame.Visible = on
	end
end

function AimController.Init(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Reticle"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, Layout.ReticleY)
	Layout.Square(frame, Layout.ReticleH)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 25
	frame.Visible = false
	frame.Parent = gui
	reticle = frame

	-- four ticks around a centre pip: reads at any size, never hides the target
	for i, offset in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
		local tick = Instance.new("Frame")
		tick.Name = "Tick" .. i
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5 + offset.X * 0.5, 0.5 + offset.Y * 0.5)
		tick.Size = if offset.X == 0
			then UDim2.fromScale(0.09, 0.3)
			else UDim2.fromScale(0.3, 0.09)
		tick.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
		tick.BorderSizePixel = 0
		tick.ZIndex = 25
		tick.Parent = frame
	end
	local pip = Instance.new("Frame")
	pip.Name = "Pip"
	pip.AnchorPoint = Vector2.new(0.5, 0.5)
	pip.Position = UDim2.fromScale(0.5, 0.5)
	pip.Size = UDim2.fromScale(0.16, 0.16)
	pip.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	pip.BorderSizePixel = 0
	pip.ZIndex = 26
	local pipCorner = Instance.new("UICorner")
	pipCorner.CornerRadius = UDim.new(1, 0)
	pipCorner.Parent = pip
	pip.Parent = frame

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		while true do
			if enabled then
				refreshIgnore()
				refreshTargets()
			end
			task.wait(0.25)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not enabled then
			aimPoint = nil
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local screenX, screenY = viewport.X * 0.5, viewport.Y * RETICLE_Y
		local ray = camera:ViewportPointToRay(screenX, screenY)

		params.FilterDescendantsInstances = ignoreList
		local hit = workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, params)
		local point = hit and hit.Position or (ray.Origin + ray.Direction * MAX_RANGE)

		-- soft assist: if a humanoid sits near the reticle and is not behind
		-- something, snap to their chest. Aiming stays yours; this only forgives
		-- the last few pixels, which matters a lot on a phone.
		local best: BasePart? = nil
		local bestDistance = viewport.Y * ASSIST_FRACTION
		for _, root in targets do
			local screen, onScreen = camera:WorldToViewportPoint(root.Position)
			if onScreen then
				local offset = (Vector2.new(screen.X, screen.Y) - Vector2.new(screenX, screenY)).Magnitude
				if offset < bestDistance then
					bestDistance = offset
					best = root
				end
			end
		end
		aimPoint = best and best.Position or point

		local color = best and Color3.fromRGB(255, 96, 84) or Color3.fromRGB(255, 250, 240)
		for _, tick in frame:GetChildren() do
			if tick:IsA("Frame") then
				tick.BackgroundColor3 = color
			end
		end
		-- the reticle tightens when it has something to lock onto
		frame.Size = UDim2.fromScale(1, best and Layout.ReticleH * 0.78 or Layout.ReticleH)
	end)
end

return AimController
