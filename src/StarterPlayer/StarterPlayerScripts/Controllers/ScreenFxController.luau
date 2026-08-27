--!strict
-- Screen juice: camera shake on hits, driven by the server's ScreenFx remote.
-- Uses Humanoid.CameraOffset with exponential decay — cheap and mobile-safe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Remotes)

local ScreenFxController = {}

local player = Players.LocalPlayer

local magnitude = 0
local rng = Random.new()

function ScreenFxController.Init(_gui: ScreenGui)
	Remotes.Get("ScreenFx").OnClientEvent:Connect(function(kind, intensity)
		if kind == "shake" then
			magnitude = math.clamp(tonumber(intensity) or 0.5, 0, 3)
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
