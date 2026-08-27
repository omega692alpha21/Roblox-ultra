--!strict
-- Catch-all client error display. Runs from ReplicatedFirst so it is alive
-- before anything else, and listens to ScriptContext so it catches errors
-- from scripts that die before their own handlers ever run.
--
-- This exists because a dead client script is otherwise invisible from a
-- phone: no HUD appears and there is nothing on screen saying why.

local Players = game:GetService("Players")
local ScriptContext = game:GetService("ScriptContext")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "ErrorHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local list = Instance.new("Frame")
list.AnchorPoint = Vector2.new(0, 0)
list.Position = UDim2.fromOffset(8, 180)
list.Size = UDim2.new(0, 700, 0, 300)
list.BackgroundTransparency = 1
list.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.Parent = list

local shown = 0
local seen: { [string]: boolean } = {}

local function show(text: string)
	if shown >= 6 or seen[text] then
		return
	end
	seen[text] = true
	shown += 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 34)
	label.BackgroundColor3 = Color3.fromRGB(150, 24, 24)
	label.BackgroundTransparency = 0.08
	label.Font = Enum.Font.Code
	label.TextSize = 15
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = list
end

ScriptContext.Error:Connect(function(message: string, trace: string)
	show(("CLIENT ERROR: %s"):format(tostring(message):sub(1, 150)))
	local firstLine = tostring(trace):split("\n")[1]
	if firstLine and #firstLine > 0 then
		show("  at " .. firstLine:sub(1, 120))
	end
end)

-- a small always-on stamp: if this is missing, ReplicatedFirst itself is not
-- running and the problem is upstream of every controller
local stamp = Instance.new("TextLabel")
stamp.AnchorPoint = Vector2.new(1, 0)
stamp.Position = UDim2.new(1, -8, 0, 8)
stamp.Size = UDim2.fromOffset(150, 20)
stamp.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
stamp.BackgroundTransparency = 0.35
stamp.Font = Enum.Font.Code
stamp.TextSize = 13
stamp.TextColor3 = Color3.fromRGB(120, 255, 170)
stamp.Text = "client ok · b" .. tostring(game.PlaceVersion)
stamp.Parent = gui

task.delay(6, function()
	local hud = playerGui:FindFirstChild("LunchMoneyLegends")
	local toys = playerGui:FindFirstChild("ToyUI")
	if not hud then
		show("HUD MISSING: Client.client.luau never built its ScreenGui")
	end
	if not toys then
		show("TOY UI MISSING: ToyController never ran")
	end
end)
