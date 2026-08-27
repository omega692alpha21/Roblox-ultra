--!strict
-- MILLIONS CLUB — client: toasts, member HUD, profile editor, directory.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Club"):WaitForChild("ClubConfig"))
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(212, 175, 85)
local BG = Color3.fromRGB(18, 16, 20)
local CREAM = Color3.fromRGB(240, 234, 222)

local gui = Instance.new("ScreenGui")
gui.Name = "MillionsClubUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Michroma
	l.TextColor3 = CREAM
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.Michroma
	b.TextColor3 = BG
	b.BackgroundColor3 = GOLD
	b.TextScaled = true
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	b.Activated:Connect(onClick)
	return b
end

-- membership status chip + seats counter
local chip = Instance.new("Frame")
chip.AnchorPoint = Vector2.new(0.5, 0)
chip.Position = UDim2.new(0.5, 0, 0, 10)
chip.Size = UDim2.fromOffset(280, 44)
chip.BackgroundColor3 = BG
chip.BackgroundTransparency = 0.15
chip.Parent = gui
local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0, 10)
chipCorner.Parent = chip
local chipStroke = Instance.new("UIStroke")
chipStroke.Color = GOLD
chipStroke.Thickness = 2
chipStroke.Parent = chip
local chipLabel = label({ Size = UDim2.fromScale(1, 1), Text = "MILLIONS CLUB", TextColor3 = GOLD, Parent = chip })

task.spawn(function()
	while true do
		local count = ReplicatedStorage:GetAttribute("MemberCount")
		local isMember = player:GetAttribute("ClubMember") == true
		local seats = typeof(count) == "number" and count or 0
		chipLabel.Text = isMember and "💎 MEMBER" or ("MILLIONS CLUB · %d/%d"):format(seats, Config.MaxMembers)
		task.wait(2)
	end
end)

-- toasts
Remotes.Get("Notify").OnClientEvent:Connect(function(message, kind)
	if typeof(message) ~= "string" then
		return
	end
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -30)
	toast.Size = UDim2.fromOffset(430, 48)
	toast.BackgroundColor3 = BG
	toast.BackgroundTransparency = 0.1
	toast.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = kind == "bad" and Color3.fromRGB(180, 60, 60) or GOLD
	stroke.Thickness = 2
	stroke.Parent = toast
	label({ Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Text = message, TextScaled = false, TextSize = 16, TextWrapped = true, Parent = toast })
	task.delay(4.5, function()
		toast:Destroy()
	end)
end)

-- profile editor + directory (members)
local function tagPicker(parent: Instance, title: string, options: { string }, selected: { [string]: boolean }, yOffset: number)
	label({ Position = UDim2.fromOffset(14, yOffset), Size = UDim2.new(1, -28, 0, 22), Text = title, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 15, Parent = parent })
	local holder = Instance.new("Frame")
	holder.Position = UDim2.fromOffset(14, yOffset + 26)
	holder.Size = UDim2.new(1, -28, 0, 84)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(118, 24)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.Parent = holder
	for _, option in options do
		local b: TextButton
		b = button({ Text = option, TextScaled = false, TextSize = 11, BackgroundColor3 = Color3.fromRGB(40, 38, 44), TextColor3 = CREAM }, function()
			(selected :: any)[option] = if selected[option] then nil else true
			b.BackgroundColor3 = if selected[option] then GOLD else Color3.fromRGB(40, 38, 44)
			b.TextColor3 = if selected[option] then BG else CREAM
		end)
		b.Parent = holder
	end
end

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(430, 380)
panel.BackgroundColor3 = BG
panel.Visible = false
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GOLD
panelStroke.Thickness = 3
panelStroke.Parent = panel
label({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28), Text = "YOUR MEMBER PROFILE", TextColor3 = GOLD, Parent = panel })

local myInterests: { [string]: boolean } = {}
local myLookingFor: { [string]: boolean } = {}
tagPicker(panel, "INTERESTS (up to 5)", Config.Interests, myInterests, 48)
tagPicker(panel, "LOOKING FOR (up to 5)", Config.LookingFor, myLookingFor, 172)
local save = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(180, 40), Text = "SAVE" }, function()
	local interests, lookingFor = {}, {}
	for tag in myInterests do
		table.insert(interests, tag)
	end
	for tag in myLookingFor do
		table.insert(lookingFor, tag)
	end
	Remotes.Get("SetProfile"):FireServer(interests, lookingFor)
	panel.Visible = false
end)
save.Parent = panel

local directory = Instance.new("Frame")
directory.AnchorPoint = Vector2.new(0.5, 0.5)
directory.Position = UDim2.fromScale(0.5, 0.5)
directory.Size = UDim2.fromOffset(460, 420)
directory.BackgroundColor3 = BG
directory.Visible = false
directory.Parent = gui
local dirCorner = Instance.new("UICorner")
dirCorner.CornerRadius = UDim.new(0, 14)
dirCorner.Parent = directory
local dirStroke = Instance.new("UIStroke")
dirStroke.Color = GOLD
dirStroke.Thickness = 3
dirStroke.Parent = directory
label({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28), Text = "MEMBER DIRECTORY", TextColor3 = GOLD, Parent = directory })
local dirList = Instance.new("ScrollingFrame")
dirList.Position = UDim2.fromOffset(12, 46)
dirList.Size = UDim2.new(1, -24, 1, -58)
dirList.BackgroundTransparency = 1
dirList.ScrollBarThickness = 6
dirList.AutomaticCanvasSize = Enum.AutomaticSize.Y
dirList.CanvasSize = UDim2.new()
dirList.Parent = directory
local dirLayout = Instance.new("UIListLayout")
dirLayout.Padding = UDim.new(0, 6)
dirLayout.Parent = dirList

local function refreshDirectory()
	for _, child in dirList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rows = Remotes.GetFunction("GetDirectory"):InvokeServer()
	if typeof(rows) ~= "table" then
		return
	end
	for i, row in rows :: { any } do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 64)
		card.BackgroundColor3 = Color3.fromRGB(28, 26, 32)
		card.LayoutOrder = i
		card.Parent = dirList
		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card
		label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), Text = "💎 " .. tostring(row.name), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 16, TextColor3 = GOLD, Parent = card })
		label({ Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 16), Text = "Interests: " .. table.concat(row.interests or {}, ", "), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 12, Parent = card })
		label({ Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 16), Text = "Looking for: " .. table.concat(row.lookingFor or {}, ", "), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 12, Parent = card })
	end
end

-- member nav (only for members)
local nav = Instance.new("Frame")
nav.Position = UDim2.fromOffset(12, 90)
nav.Size = UDim2.fromOffset(120, 100)
nav.BackgroundTransparency = 1
nav.Visible = false
nav.Parent = gui
local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = nav
local profileButton = button({ Size = UDim2.fromOffset(120, 40), Text = "PROFILE", TextScaled = false, TextSize = 14 }, function()
	directory.Visible = false
	panel.Visible = not panel.Visible
end)
profileButton.Parent = nav
local dirButton = button({ Size = UDim2.fromOffset(120, 40), Text = "DIRECTORY", TextScaled = false, TextSize = 14 }, function()
	panel.Visible = false
	directory.Visible = not directory.Visible
	if directory.Visible then
		task.spawn(refreshDirectory)
	end
end)
dirButton.Parent = nav

task.spawn(function()
	while true do
		nav.Visible = player:GetAttribute("ClubMember") == true
		task.wait(2)
	end
end)

local _ = TweenService
print("[MillionsClub] client ready")
