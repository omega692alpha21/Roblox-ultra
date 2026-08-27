--!strict
-- The toy controls: a row of toy chips and one big ACTION button, because
-- Roblox does not give Tools a dependable fire button on phones. Tapping a
-- chip selects a toy; the action button throws it where the camera looks.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local ToyController = {}

local player = Players.LocalPlayer

type Toy = { id: string, label: string, icon: string }
local TOYS: { Toy } = {
	{ id = "slingshot", label = "Slingshot", icon = "🪨" },
	{ id = "snowball", label = "Snowballs", icon = "❄️" },
	{ id = "firecracker", label = "Firecrackers", icon = "🧨" },
}

local selected = "slingshot"

function ToyController.Init(_shared: ScreenGui)
	-- own ScreenGui, high DisplayOrder: the toy controls must never be hidden
	-- behind another panel or lost if a shared gui is rebuilt
	local gui = Instance.new("ScreenGui")
	gui.Name = "ToyUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 60
	gui.Parent = (game:GetService("Players").LocalPlayer :: any):WaitForChild("PlayerGui")
	local function ammoOf(id: string): number
		if id == "slingshot" then
			return math.huge
		end
		return tonumber(player:GetAttribute("Ammo_" .. id)) or 0
	end
	local function owns(id: string): boolean
		if id == "slingshot" then
			return player:GetAttribute("Owns_slingshot") == true
		end
		return ammoOf(id) > 0
	end

	-- ---- the action button ----
	local action = Instance.new("TextButton")
	action.Name = "ToyAction"
	action.AnchorPoint = Vector2.new(1, 1)
	action.Position = UDim2.new(1, -28, 1, -150)
	action.Size = UDim2.fromOffset(86, 86)
	action.BackgroundColor3 = Color3.fromRGB(226, 74, 62)
	action.Font = Enum.Font.FredokaOne
	action.Text = "🪨"
	action.TextScaled = true
	action.TextColor3 = Color3.fromRGB(255, 250, 240)
	action.AutoButtonColor = true
	action.ZIndex = 30
	action.Visible = false
	action.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = action
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(255, 244, 220)
	ring.Thickness = 3
	ring.Transparency = 0.25
	ring.Parent = action

	local ammoTag = Instance.new("TextLabel")
	ammoTag.AnchorPoint = Vector2.new(0.5, 0)
	ammoTag.Position = UDim2.new(0.5, 0, 1, 2)
	ammoTag.Size = UDim2.fromOffset(86, 20)
	ammoTag.BackgroundTransparency = 1
	ammoTag.Font = Enum.Font.FredokaOne
	ammoTag.TextScaled = true
	ammoTag.TextColor3 = Color3.fromRGB(255, 244, 220)
	ammoTag.TextStrokeTransparency = 0.4
	ammoTag.Text = ""
	ammoTag.ZIndex = 30
	ammoTag.Parent = action

	local function fire()
		local camera = workspace.CurrentCamera
		if not camera or not owns(selected) then
			return
		end
		Remotes.Get("UseToy"):FireServer(selected, camera.CFrame.LookVector)
		-- a quick squash so the tap feels answered
		action.Size = UDim2.fromOffset(78, 78)
		task.delay(0.08, function()
			action.Size = UDim2.fromOffset(86, 86)
		end)
	end
	action.Activated:Connect(fire)
	ContextActionService:BindAction("ThrowToy", function(_, state)
		if state == Enum.UserInputState.Begin then
			fire()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

	-- ---- the toy chips ----
	local rail = Instance.new("Frame")
	rail.Name = "ToyRail"
	rail.AnchorPoint = Vector2.new(1, 1)
	rail.Position = UDim2.new(1, -28, 1, -244)
	rail.Size = UDim2.fromOffset(86, 3 * 42)
	rail.BackgroundTransparency = 1
	rail.ZIndex = 30
	rail.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = rail

	local chips: { [string]: TextButton } = {}
	for _, toy in TOYS do
		local chip = Instance.new("TextButton")
		chip.Name = toy.id
		chip.Size = UDim2.fromOffset(86, 36)
		chip.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
		chip.BackgroundTransparency = 0.12
		chip.Font = Enum.Font.FredokaOne
		chip.TextScaled = true
		chip.TextColor3 = Color3.fromRGB(240, 236, 226)
		chip.Text = toy.icon
		chip.AutoButtonColor = true
		chip.ZIndex = 30
		chip.Visible = false
		chip.Parent = rail
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = chip
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(245, 197, 49)
		st.Thickness = 2
		st.Transparency = 1
		st.Parent = chip
		chip.Activated:Connect(function()
			selected = toy.id
			action.Text = toy.icon
		end)
		chips[toy.id] = chip
	end

	task.spawn(function()
		while true do
			local anyOwned = false
			for _, toy in TOYS do
				local chip = chips[toy.id]
				local have = owns(toy.id)
				chip.Visible = have
				if have then
					anyOwned = true
					local stroke = chip:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = selected == toy.id and 0 or 1
					end
				end
			end
			if not owns(selected) then
				for _, toy in TOYS do
					if owns(toy.id) then
						selected = toy.id
						action.Text = toy.icon
						break
					end
				end
			end
			action.Visible = anyOwned
			local left = ammoOf(selected)
			ammoTag.Text = left == math.huge and "∞" or tostring(left)
			task.wait(0.35)
		end
	end)
end

return ToyController
