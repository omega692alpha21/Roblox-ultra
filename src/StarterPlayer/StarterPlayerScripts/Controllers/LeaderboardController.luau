--!strict
-- Top panel: global top-50 lists (earned / aura) pushed by the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local UIBuilder = require(script.Parent.UIBuilder)

local LeaderboardController = {}

function LeaderboardController.Init(gui: ScreenGui)
	local _, content = UIBuilder.Panel(gui, "Top", "TROPHY HALL — GLOBAL TOP 50")

	local data: { [string]: { { name: string, value: number } } } = { cash = {}, aura = {} }
	local currentTab = "cash"

	local tabs = UIBuilder.Frame({
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabs

	local listFrame = UIBuilder.Frame({
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local list = UIBuilder.List(listFrame)

	local rowLabels: { TextLabel } = {}
	for i = 1, 50 do
		local row = UIBuilder.Label({
			Size = UDim2.new(1, -12, 0, 24),
			Text = "",
			TextScaled = false,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = i <= 3 and Palette.BusYellow or Palette.Chalk,
			LayoutOrder = i,
			Visible = false,
			Parent = list,
		})
		rowLabels[i] = row
	end

	local function render()
		local rows = data[currentTab] or {}
		for i = 1, 50 do
			local label = rowLabels[i]
			local row = rows[i]
			if row then
				label.Visible = true
				label.Text = ("%2d.  %s  —  %s"):format(i, row.name, NumberFormat.Abbreviate(row.value))
			else
				label.Visible = false
			end
		end
	end

	local tabButtons: { [string]: TextButton } = {}
	for _, spec in { { key = "cash", label = "TOP EARNERS" }, { key = "aura", label = "MOST AURA" } } do
		local button = UIBuilder.Button({
			Size = UDim2.fromOffset(160, 36),
			Text = spec.label,
			BackgroundColor3 = spec.key == "cash" and Palette.CashGreen or Palette.PanelBg,
		}, function()
			currentTab = spec.key
			for key, tabButton in tabButtons do
				tabButton.BackgroundColor3 = key == currentTab and Palette.CashGreen or Palette.PanelBg
			end
			render()
		end)
		UIBuilder.Round(button, 10)
		UIBuilder.Stroke(button, Palette.CashGreen, 2)
		button.Parent = tabs
		tabButtons[spec.key] = button
	end

	Remotes.Get("LeaderboardUpdate").OnClientEvent:Connect(function(kind, rows)
		if typeof(kind) == "string" and typeof(rows) == "table" then
			data[kind] = rows :: any
			render()
		end
	end)
end

return LeaderboardController
