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
