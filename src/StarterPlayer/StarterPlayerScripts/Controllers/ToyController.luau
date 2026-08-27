--!strict
-- The toy controls: a rail of tool tiles down the right edge and one big THROW
-- button under the thumb, because Roblox does not give Tools a dependable fire
-- button on phones. Tapping a tile selects a tool; the throw button sends it
-- wherever the reticle is pointing.
--
-- Tools live on the right, opposite the menus, so the hand that picks a tool
-- is the hand that throws it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
local Layout = require(script.Parent.Layout)
local AimController = require(script.Parent.AimController)

local ToyController = {}

local player = Players.LocalPlayer

type Toy = { id: string, label: string, icon: string }
local TOYS: { Toy } = {
	{ id = "slingshot", label = "Slingshot", icon = "🎯" },
	{ id = "snowball", label = "Snowballs", icon = "❄️" },
	{ id = "firecracker", label = "Firecrackers", icon = "🧨" },
}

local selected = "slingshot"

function ToyController.Init(gui: ScreenGui)
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
	action.LayoutOrder = Layout.Order.Toy
	action.BackgroundColor3 = Color3.fromRGB(226, 74, 62)
	action.Font = Enum.Font.FredokaOne
	action.Text = "🎯"
	action.TextScaled = true
	action.TextColor3 = Color3.fromRGB(255, 250, 240)
	action.AutoButtonColor = true
	action.ZIndex = 30
	action.Visible = false
	Layout.ActionSlot(action, "Toy", gui)
	Layout.FitText(action, 34)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = action
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(255, 244, 220)
	ring.Thickness = 3
	ring.Transparency = 0.25
	ring.Parent = action

	local function fire()
		local camera = workspace.CurrentCamera
		if not camera or not owns(selected) then
			return
		end
		-- the world point under the reticle, not a camera vector: the server
		-- solves the arc that lands there
		local aim = AimController.Point() or (camera.CFrame.Position + camera.CFrame.LookVector * 80)
		Remotes.Get("UseToy"):FireServer(selected, aim)
		-- a quick squash so the tap feels answered; the aspect constraint keeps
		-- it square, so only the bounding box moves
		local slot = Layout.Actions.Toy.size
		action.Size = UDim2.fromScale(1, slot * 0.86)
		task.delay(0.08, function()
			action.Size = UDim2.fromScale(1, slot)
		end)
	end
	action.Activated:Connect(fire)
	ContextActionService:BindAction("ThrowToy", function(_, state)
		if state == Enum.UserInputState.Begin then
			fire()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

	-- ---- the hotbar, bottom centre ----
	-- The toys used to live in a rail down the right edge, which put them in
	-- the same band as the action buttons and made the corner unreadable. They
	-- are slots now, over the health bars, where a game puts its items.
	local rail = Layout.Hotbar(gui)

	local chips: { [string]: TextButton } = {}
	for index, toy in TOYS do
		local chip = Instance.new("TextButton")
		chip.Name = toy.id
		Layout.Square(chip, 1)
		chip.LayoutOrder = index
		chip.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
		chip.BackgroundTransparency = 0.15
		chip.Font = Enum.Font.FredokaOne
		chip.TextColor3 = Color3.fromRGB(240, 236, 226)
		chip.Text = toy.icon
		chip.AutoButtonColor = true
		chip.ZIndex = 29
		chip.Visible = false
		chip.Parent = rail
		Layout.FitText(chip, 30)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.22, 0)
		c.Parent = chip
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(245, 197, 49)
		st.Thickness = 2
		st.Transparency = 1
		st.Parent = chip
		-- the count rides the corner of its own tile
		local count = Instance.new("TextLabel")
		count.Name = "Count"
		count.AnchorPoint = Vector2.new(1, 1)
		count.Position = UDim2.fromScale(0.96, 0.98)
		count.Size = UDim2.fromScale(0.5, 0.32)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.FredokaOne
		count.TextScaled = true
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.TextColor3 = Color3.fromRGB(255, 244, 220)
		count.TextStrokeTransparency = 0.4
		count.Text = ""
		count.ZIndex = 30
		count.Parent = chip
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
					local count = chip:FindFirstChild("Count") :: TextLabel?
					if count then
						local left = ammoOf(toy.id)
						count.Text = left == math.huge and "" or tostring(left)
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
			-- the reticle is only meaningful while there is something to throw
			AimController.SetEnabled(anyOwned)
			task.wait(0.35)
		end
	end)
end

return ToyController
