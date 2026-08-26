--!strict
-- Reputation panel: the five tracks with progress bars — Popular, Athletic,
-- Smart, Creative, Troublemaker. Your dominant track is your title.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Palette = require(ReplicatedStorage.Shared.Palette)
local UIBuilder = require(script.Parent.UIBuilder)

local RepController = {}

local player = Players.LocalPlayer

local TRACKS = {
	{ attr = "RepPopular", label = "👑 POPULAR", color = Color3.fromRGB(255, 196, 60) },
	{ attr = "RepAthletic", label = "🏋 ATHLETIC", color = Color3.fromRGB(226, 74, 62) },
	{ attr = "RepSmart", label = "📖 SMART", color = Color3.fromRGB(64, 148, 236) },
	{ attr = "RepCreative", label = "🎨 CREATIVE", color = Color3.fromRGB(168, 90, 220) },
	{ attr = "RepTroublemaker", label = "💀 TROUBLEMAKER", color = Color3.fromRGB(150, 158, 166) },
}

local function levelFor(points: number): number
	return math.floor(math.sqrt(math.max(points, 0) / 40))
end

function RepController.Init(gui: ScreenGui)
	local panel, content = UIBuilder.Panel(gui, "Rep", "BECOME LEGENDARY")

	local titleLabel = UIBuilder.Label({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "You are: New Kid",
		TextColor3 = Palette.BusYellow,
		Parent = content,
	})

	local rows: { { fill: Frame, value: TextLabel, track: { attr: string, label: string, color: Color3 } } } = {}
	for i, track in TRACKS do
		local y = 20 + i * 56
		UIBuilder.Label({
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(0.45, 0, 0, 24),
			Text = track.label,
			TextColor3 = track.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 17,
			Parent = content,
		})
		local barBg = UIBuilder.Frame({
			Position = UDim2.new(0, 0, 0, y + 26),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundColor3 = Color3.fromRGB(30, 40, 30),
			Parent = content,
		})
		UIBuilder.Round(barBg, 999)
		local fill = UIBuilder.Frame({
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = track.color,
			Parent = barBg,
		})
		UIBuilder.Round(fill, 999)
		local value = UIBuilder.Label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y),
			Size = UDim2.fromOffset(120, 24),
			Text = "Lv 0",
			TextColor3 = Palette.Chalk,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = false,
			TextSize = 15,
			Parent = content,
		})
		rows[i] = { fill = fill, value = value, track = track }
	end

	UIBuilder.Label({
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Everything you do shifts how the school sees you. Nothing is locked.",
		TextColor3 = Palette.Chalk,
		TextScaled = false,
		TextSize = 14,
		Parent = content,
	})

	RunService.Heartbeat:Connect(function()
		if not panel.Visible then
			return
		end
		local title = player:GetAttribute("RepTitle")
		titleLabel.Text = "You are: " .. (typeof(title) == "string" and title or "New Kid")
		for _, row in rows do
			local points = player:GetAttribute(row.track.attr)
			local pointsNum = typeof(points) == "number" and points or 0
			local level = levelFor(pointsNum)
			local currentFloor = 40 * level * level
			local nextGate = 40 * (level + 1) * (level + 1)
			local alpha = math.clamp((pointsNum - currentFloor) / (nextGate - currentFloor), 0, 1)
			row.fill.Size = UDim2.fromScale(alpha, 1)
			row.value.Text = ("Lv %d · %d"):format(level, pointsNum)
		end
	end)
end

return RepController
