--!strict
-- The House Cup: a chip on the HUD and the standings behind it.
--
-- The chip is the point. A number that only exists in a menu is a number
-- nobody competes over, so your house, its position and the time left in the
-- term sit on screen the whole time, under the status pills.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Houses = require(ReplicatedStorage.Config.Houses)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Layout = require(script.Parent.Layout)
local UIBuilder = require(script.Parent.UIBuilder)

local HouseController = {}

local player = Players.LocalPlayer

local function standings(): { { house: Houses.House, points: number } }
	local rows = {}
	for _, house in Houses.List do
		local value = ReplicatedStorage:GetAttribute("House_" .. house.id)
		table.insert(rows, { house = house, points = typeof(value) == "number" and value or 0 })
	end
	table.sort(rows, function(a, b)
		return a.points > b.points
	end)
	return rows
end

function HouseController.Init(gui: ScreenGui)
	local chip = UIBuilder.Button({
		Name = "HouseChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, Layout.HouseY),
		Size = UDim2.fromScale(Layout.HouseW, Layout.HouseH),
		Text = "",
		BackgroundColor3 = Palette.PanelBg,
		BackgroundTransparency = 0.25,
	}, function()
		UIBuilder.Toggle("Houses")
	end)
	chip.ZIndex = 26
	UIBuilder.Round(chip, 999)
	local ring = UIBuilder.Stroke(chip, Palette.White, 2)
	Layout.FitText(chip, 20)
	chip.Parent = gui

	local _, content = UIBuilder.Panel(gui, "Houses", "THE HOUSE CUP")
	local list = UIBuilder.List(content)

	local function renderPanel()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local mine = player:GetAttribute("House")
		for index, row in standings() do
			local card = UIBuilder.Frame({
				Size = UDim2.new(1, -8, 0, 62),
				BackgroundColor3 = Palette.PanelBg,
				BackgroundTransparency = row.house.id == mine and 0.1 or 0.4,
				LayoutOrder = index,
				Parent = list,
			})
			UIBuilder.Round(card, 10)
			UIBuilder.Stroke(card, row.house.color, row.house.id == mine and 3 or 1.5)
			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -120, 0, 26),
				Text = ("%d.  %s %s"):format(index, row.house.crest, row.house.name),
				TextColor3 = row.house.color,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
			UIBuilder.Label({
				Position = UDim2.fromOffset(12, 34),
				Size = UDim2.new(1, -120, 0, 18),
				Text = row.house.motto,
				TextColor3 = Color3.fromRGB(158, 170, 186),
				TextScaled = false,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = card,
			})
			UIBuilder.Label({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(104, 30),
				Text = tostring(row.points),
				TextColor3 = row.house.color,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = card,
			})
		end
		local contribution = player:GetAttribute("HouseContribution")
		UIBuilder.Label({
			Size = UDim2.new(1, -8, 0, 26),
			Text = ("You have put in %d points this term."):format(
				typeof(contribution) == "number" and contribution or 0
			),
			TextColor3 = Palette.Chalk,
			TextScaled = false,
			TextSize = 14,
			LayoutOrder = 99,
			Parent = list,
		})
	end

	local clock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
        if clock < 1 then
			return
		end
		clock = 0
		local mine = player:GetAttribute("House")
		local house = Houses.Get(typeof(mine) == "string" and mine or nil)
		if not house then
			chip.Text = "THE HOUSE CUP"
			return
		end
		ring.Color = house.color
		local place = 1
		for index, row in standings() do
			if row.house.id == house.id then
				place = index
			end
		end
		local endsAt = ReplicatedStorage:GetAttribute("HouseTermEndsAt")
		local left = math.max(0, (typeof(endsAt) == "number" and endsAt or 0) - os.time())
		chip.Text = ("%s %s  ·  %s  ·  %d:%02d"):format(
			house.crest,
			house.name,
			(place == 1 and "1st") or (place == 2 and "2nd") or (place == 3 and "3rd") or "4th",
			math.floor(left / 60),
			left % 60
		)
		if (gui:FindFirstChild("Houses") :: any) and (gui.Houses :: any).Visible then
			renderPanel()
		end
	end)
end

return HouseController
