--!strict
-- The detention countdown: a barred banner across the top of the screen with
-- the sentence ticking down, and the one way out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Config.Products)
local Remotes = require(ReplicatedStorage.Remotes)

local JailController = {}

local player = Players.LocalPlayer
local _ = player

function JailController.Init(gui: ScreenGui)
	local panel = Instance.new("Frame")
	panel.Name = "JailPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 150) -- below the minimap/status row
	panel.Size = UDim2.fromOffset(320, 118)
	panel.BackgroundColor3 = Color3.fromRGB(24, 20, 20)
	panel.BackgroundTransparency = 0.06
	panel.Visible = false
	panel.ZIndex = 40
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(198, 74, 62)
	stroke.Thickness = 3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 24)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 122, 108)
	title.Text = "DETENTION"
	title.ZIndex = 41
	title.Parent = panel

	local clock = Instance.new("TextLabel")
	clock.Size = UDim2.new(1, -20, 0, 38)
	clock.Position = UDim2.fromOffset(10, 32)
	clock.BackgroundTransparency = 1
	clock.Font = Enum.Font.FredokaOne
	clock.TextScaled = true
	clock.TextColor3 = Color3.fromRGB(255, 244, 232)
	clock.Text = "0:00"
	clock.ZIndex = 41
	clock.Parent = panel

	local skip = Instance.new("TextButton")
	skip.Size = UDim2.new(1, -24, 0, 34)
	skip.Position = UDim2.fromOffset(12, 74)
	skip.BackgroundColor3 = Color3.fromRGB(245, 197, 49)
	skip.Font = Enum.Font.FredokaOne
	skip.TextScaled = true
	skip.TextColor3 = Color3.fromRGB(30, 24, 16)
	skip.Text = ("WALK OUT — %d R$"):format(Products.GamePasses.JailPass.price)
	skip.AutoButtonColor = true
	skip.ZIndex = 41
	skip.Parent = panel
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skip
	skip.Activated:Connect(function()
		Remotes.Get("RequestJailSkip"):FireServer()
	end)

	Remotes.Get("JailState").OnClientEvent:Connect(function(secondsLeft, canSkip)
		local left = tonumber(secondsLeft) or 0
		if left <= 0 then
			panel.Visible = false
			return
		end
		panel.Visible = true
		clock.Text = ("%d:%02d"):format(math.floor(left / 60), left % 60)
		skip.Visible = canSkip == true
	end)
end

return JailController
