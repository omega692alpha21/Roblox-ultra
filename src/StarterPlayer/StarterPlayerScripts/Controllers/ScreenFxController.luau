--!strict
-- Screen juice: camera shake on hits, driven by the server's ScreenFx remote.
-- Uses Humanoid.CameraOffset with exponential decay — cheap and mobile-safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Remotes)

local ScreenFxController = {}

local player = Players.LocalPlayer

local magnitude = 0
local rng = Random.new()

function ScreenFxController.Init(gui: ScreenGui)
	-- A red edge that blooms and fades on damage. Health that only moves a bar
	-- at the bottom of the screen is a number; the flash is what tells you, in
	-- the moment you are hit, that you were hit.
	local hurt = Instance.new("ImageLabel")
	hurt.Name = "HurtVignette"
	hurt.BackgroundTransparency = 1
	hurt.Image = "rbxasset://textures/ui/Vignette.png"
	hurt.ImageColor3 = Color3.fromRGB(180, 24, 24)
	hurt.ImageTransparency = 1
	hurt.Size = UDim2.fromScale(1, 1)
	hurt.ScaleType = Enum.ScaleType.Stretch
	hurt.ZIndex = 90
	hurt.Active = false
	hurt.Parent = gui

	Remotes.Get("ScreenFx").OnClientEvent:Connect(function(kind, intensity)
		if kind == "shake" then
			magnitude = math.clamp(tonumber(intensity) or 0.5, 0, 3)
		elseif kind == "hurt" then
			local strength = math.clamp(tonumber(intensity) or 0.5, 0.2, 1)
			magnitude = math.max(magnitude, strength * 0.9)
			hurt.ImageTransparency = 1 - 0.55 * strength
			TweenService:Create(hurt, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				ImageTransparency = 1,
			}):Play()
		end
	end)

	-- landing impact: small camera dip scaled by fall speed
	local function hookCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		local lastVelY = 0
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if root then
			task.spawn(function()
				while character.Parent do
					lastVelY = root.AssemblyLinearVelocity.Y
					task.wait(0.05)
				end
			end)
		end
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed then
				magnitude = math.clamp(math.abs(lastVelY) / 60, 0.15, 1.1)
			end
		end)
	end
	if player.Character then
		hookCharacter(player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)

	RunService.RenderStepped:Connect(function(dt: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if magnitude > 0.02 then
			humanoid.CameraOffset = Vector3.new(
				rng:NextNumber(-magnitude, magnitude),
				rng:NextNumber(-magnitude, magnitude) * 0.6,
				0
			)
			magnitude *= math.pow(0.001, dt) -- fast exponential decay (~0.7s)
		elseif humanoid.CameraOffset.Magnitude > 0 then
			humanoid.CameraOffset = Vector3.zero
			magnitude = 0
		end
	end)
end

return ScreenFxController
