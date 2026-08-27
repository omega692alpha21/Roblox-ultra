--!strict
-- Toys fire where the camera is looking. The client only sends a direction;
-- the server owns cooldowns, ammo and every hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Remotes)

local ToyController = {}

local player = Players.LocalPlayer

function ToyController.Init(gui: ScreenGui)
	local function hookTool(tool: Instance)
		if not tool:IsA("Tool") then
			return
		end
		local toyId = tool:GetAttribute("ToyId")
		if typeof(toyId) ~= "string" then
			return
		end
		tool.Activated:Connect(function()
			local camera = workspace.CurrentCamera
			if camera then
				Remotes.Get("UseToy"):FireServer(toyId, camera.CFrame.LookVector)
			end
		end)
	end

	local function watch(container: Instance)
		for _, child in container:GetChildren() do
			hookTool(child)
		end
		container.ChildAdded:Connect(hookTool)
	end

	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		watch(backpack)
	end
	player.CharacterAdded:Connect(function(character)
		watch(character)
	end)
	if player.Character then
		watch(player.Character)
	end

	-- ammo readout under the minimap
	local ammo = Instance.new("TextLabel")
	ammo.Name = "AmmoLabel"
	ammo.AnchorPoint = Vector2.new(0, 0)
	ammo.Position = UDim2.fromOffset(14, 176)
	ammo.Size = UDim2.fromOffset(150, 22)
	ammo.BackgroundTransparency = 1
	ammo.Font = Enum.Font.FredokaOne
	ammo.TextXAlignment = Enum.TextXAlignment.Left
	ammo.TextScaled = true
	ammo.TextColor3 = Color3.fromRGB(255, 244, 220)
	ammo.TextStrokeTransparency = 0.4
	ammo.Text = ""
	ammo.Parent = gui

	task.spawn(function()
		while true do
			local character = player.Character
			local held = character and character:FindFirstChildOfClass("Tool")
			local toyId = held and held:GetAttribute("ToyId")
			if typeof(toyId) == "string" then
				local count = player:GetAttribute("Ammo_" .. toyId)
				if toyId == "slingshot" then
					ammo.Text = "🪨 ∞"
				else
					ammo.Text = (toyId == "snowball" and "❄️ " or "🧨 ") .. tostring(tonumber(count) or 0)
				end
			else
				ammo.Text = ""
			end
			task.wait(0.4)
		end
	end)

	local _ = UserInputService
end

return ToyController
