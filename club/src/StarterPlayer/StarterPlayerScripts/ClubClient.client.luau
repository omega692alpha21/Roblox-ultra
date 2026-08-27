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
gui.Name = "CultUI"
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
local chipLabel = label({ Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GOLD, Parent = chip })

task.spawn(function()
	while true do
		-- an outsider is told nothing at all
		if player:GetAttribute("Initiated") == true then
			chipLabel.Text = ("%s \u{00B7} %d REP \u{00B7} %sh"):format(
				tostring(player:GetAttribute("Rank") or "INITIATE"),
				tonumber(player:GetAttribute("Rep")) or 0,
				tostring(player:GetAttribute("Hours") or 0)
			)
			chip.Visible = true
		else
			chip.Visible = false
		end
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
		nav.Visible = player:GetAttribute("Initiated") == true
		task.wait(2)
	end
end)

-- ------------------------------------------------------------- the keypad ---
-- Four digits, no hint, no label. The same pad takes answers at the altar.
local keypadContext: string? = nil

local keypad = Instance.new("Frame")
keypad.AnchorPoint = Vector2.new(0.5, 0.5)
keypad.Position = UDim2.fromScale(0.5, 0.5)
keypad.Size = UDim2.fromOffset(260, 380)
keypad.BackgroundColor3 = Color3.fromRGB(12, 11, 14)
keypad.Visible = false
keypad.Parent = gui
local kCorner = Instance.new("UICorner")
kCorner.CornerRadius = UDim.new(0, 12)
kCorner.Parent = keypad
local kStroke = Instance.new("UIStroke")
kStroke.Color = GOLD
kStroke.Thickness = 2
kStroke.Parent = keypad

local entry = label({
	Position = UDim2.fromOffset(16, 14),
	Size = UDim2.new(1, -32, 0, 52),
	Text = "",
	TextColor3 = GOLD,
	TextScaled = false,
	TextSize = 40,
	Parent = keypad,
})
local entryStroke = Instance.new("UIStroke")
entryStroke.Color = Color3.fromRGB(52, 48, 40)
entryStroke.Thickness = 1
entryStroke.Parent = entry

local typed = ""
local function setTyped(value: string)
	typed = value
	entry.Text = value == "" and "· · · ·" or value
end

local pad = Instance.new("Frame")
pad.Position = UDim2.fromOffset(16, 74)
pad.Size = UDim2.new(1, -32, 0, 232)
pad.BackgroundTransparency = 1
pad.Parent = keypad
local padGrid = Instance.new("UIGridLayout")
padGrid.CellSize = UDim2.fromOffset(70, 52)
padGrid.CellPadding = UDim2.fromOffset(9, 9)
padGrid.Parent = pad

local function closeKeypad()
	keypad.Visible = false
	setTyped("")
end

local function submit()
	if typed == "" then
		return
	end
	local ok, result = pcall(function()
		return Remotes.GetFunction("SubmitCode"):InvokeServer(typed, keypadContext)
	end)
	setTyped("")
	if ok and typeof(result) == "table" then
		local r = result :: any
		if r.ok then
			closeKeypad()
		elseif typeof(r.message) == "string" and r.message ~= "" then
			entry.Text = r.message
			task.delay(1.6, function()
				if typed == "" then
					setTyped("")
				end
			end)
		end
	end
end

for _, digit in { "1", "2", "3", "4", "5", "6", "7", "8", "9", "←", "0", "✓" } do
	local b = button({
		Text = digit,
		TextScaled = false,
		TextSize = 22,
		BackgroundColor3 = Color3.fromRGB(28, 26, 31),
		TextColor3 = CREAM,
	}, function()
		if digit == "←" then
			setTyped(typed:sub(1, -2))
		elseif digit == "✓" then
			submit()
		elseif #typed < 4 then
			setTyped(typed .. digit)
			if #typed == 4 then
				task.delay(0.25, submit)
			end
		end
	end)
	b.Parent = pad
end

local closeButton = button({
	Position = UDim2.fromOffset(16, 320),
	Size = UDim2.new(1, -32, 0, 40),
	Text = "STEP BACK",
	TextScaled = false,
	TextSize = 14,
	BackgroundColor3 = Color3.fromRGB(28, 26, 31),
	TextColor3 = CREAM,
}, closeKeypad)
closeButton.Parent = keypad

Remotes.Get("OpenKeypad").OnClientEvent:Connect(function(context)
	keypadContext = typeof(context) == "string" and context or nil
	setTyped("")
	keypad.Visible = true
end)

-- ------------------------------------------------------ the way in, taken ---
Remotes.Get("Initiated").OnClientEvent:Connect(function(seat)
	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.ZIndex = 50
	veil.Parent = gui
	local line = label({
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.35),
		Text = "INITIATION COMPLETE",
		TextColor3 = GOLD,
		TextScaled = false,
		TextSize = 40,
		TextTransparency = 1,
		ZIndex = 51,
		Parent = veil,
	})
	local sub = label({
		Size = UDim2.fromScale(1, 0.1),
		Position = UDim2.fromScale(0, 0.55),
		Text = if typeof(seat) == "number" then ("SEAT %d OF THE FOUNDING HUNDRED"):format(seat) else "WELCOME TO CULT",
		TextColor3 = CREAM,
		TextScaled = false,
		TextSize = 18,
		TextTransparency = 1,
		ZIndex = 51,
		Parent = veil,
	})
	local fade = TweenInfo.new(1.2, Enum.EasingStyle.Quad)
	TweenService:Create(veil, fade, { BackgroundTransparency = 0 }):Play()
	task.wait(1.2)
	TweenService:Create(line, fade, { TextTransparency = 0 }):Play()
	task.wait(1)
	TweenService:Create(sub, fade, { TextTransparency = 0 }):Play()
	task.wait(2.4)
	TweenService:Create(veil, TweenInfo.new(1.6), { BackgroundTransparency = 1 }):Play()
	for _, obj in { line, sub } do
		TweenService:Create(obj, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()
	end
	task.delay(1.8, function()
		veil:Destroy()
	end)
end)

-- ---------------------------------------------------------------- the board ---
local missions = Instance.new("Frame")
missions.AnchorPoint = Vector2.new(0, 0.5)
missions.Position = UDim2.new(0, 150, 0.5, 0)
missions.Size = UDim2.fromOffset(420, 300)
missions.BackgroundColor3 = BG
missions.Visible = false
missions.Parent = gui
local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 12)
mCorner.Parent = missions
local mStroke = Instance.new("UIStroke")
mStroke.Color = GOLD
mStroke.Thickness = 2
mStroke.Parent = missions
local mList = Instance.new("ScrollingFrame")
mList.Position = UDim2.fromOffset(12, 46)
mList.Size = UDim2.new(1, -24, 1, -58)
mList.BackgroundTransparency = 1
mList.ScrollBarThickness = 3
mList.CanvasSize = UDim2.new()
mList.AutomaticCanvasSize = Enum.AutomaticSize.Y
mList.Parent = missions
local mLayout = Instance.new("UIListLayout")
mLayout.Padding = UDim.new(0, 8)
mLayout.Parent = mList
label({
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.new(1, -28, 0, 26),
	Text = "THE BOARD",
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextScaled = false,
	TextSize = 18,
	Parent = missions,
})

local function refreshMissions()
	for _, child in mList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local ok, rows = pcall(function()
		return Remotes.GetFunction("GetMissions"):InvokeServer()
	end)
	if not ok or typeof(rows) ~= "table" then
		return
	end
	for _, row in rows :: any do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -6, 0, 64)
		card.BackgroundColor3 = Color3.fromRGB(28, 26, 31)
		card.Parent = mList
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card
		label({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 18),
			Text = ("MISSION %03d"):format(row.no),
			TextColor3 = if row.done then Color3.fromRGB(120, 150, 110) else GOLD,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 13,
			Parent = card,
		})
		label({
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -20, 0, 32),
			Text = if row.done then ("✓  " .. tostring(row.text)) else tostring(row.text),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextScaled = false,
			TextSize = 15,
			Parent = card,
		})
	end
end

local boardButton = button({ Size = UDim2.fromOffset(120, 40), Text = "THE BOARD", TextScaled = false, TextSize = 14 }, function()
	panel.Visible = false
	directory.Visible = false
	missions.Visible = not missions.Visible
	if missions.Visible then
		task.spawn(refreshMissions)
	end
end)
boardButton.Parent = nav

Remotes.Get("RepChanged").OnClientEvent:Connect(function(_rep, _rank, reason)
	if typeof(reason) == "string" and reason ~= "" and missions.Visible then
		task.spawn(refreshMissions)
	end
end)

-- fragments arrive once and are never written down anywhere but here
Remotes.Get("Fragment").OnClientEvent:Connect(function(text)
	if typeof(text) ~= "string" then
		return
	end
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(460, 120)
	card.BackgroundColor3 = Color3.fromRGB(10, 9, 12)
	card.ZIndex = 40
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = card
	label({
		Size = UDim2.new(1, -30, 1, -20),
		Position = UDim2.fromOffset(15, 10),
		Text = text,
		TextColor3 = CREAM,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 18,
		ZIndex = 41,
		Parent = card,
	})
	task.delay(9, function()
		card:Destroy()
	end)
end)


-- ------------------------------------------------- declaring your own house ---
local founding = Instance.new("Frame")
founding.AnchorPoint = Vector2.new(0.5, 0.5)
founding.Position = UDim2.fromScale(0.5, 0.5)
founding.Size = UDim2.fromOffset(340, 330)
founding.BackgroundColor3 = Color3.fromRGB(12, 11, 14)
founding.Visible = false
founding.Parent = gui
local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 12)
fCorner.Parent = founding
local fStroke = Instance.new("UIStroke")
fStroke.Color = GOLD
fStroke.Thickness = 2
fStroke.Parent = founding
label({ Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 24), Text = "DECLARE YOUR HOUSE", TextColor3 = GOLD, TextScaled = false, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = founding })

local nameBox = Instance.new("TextBox")
nameBox.Position = UDim2.fromOffset(16, 44)
nameBox.Size = UDim2.new(1, -32, 0, 38)
nameBox.BackgroundColor3 = Color3.fromRGB(28, 26, 31)
nameBox.Font = Enum.Font.Michroma
nameBox.PlaceholderText = "its name"
nameBox.Text = ""
nameBox.TextColor3 = CREAM
nameBox.TextSize = 17
nameBox.ClearTextOnFocus = false
nameBox.Parent = founding
local nbCorner = Instance.new("UICorner")
nbCorner.CornerRadius = UDim.new(0, 8)
nbCorner.Parent = nameBox

local chosenSigil = 1
local chosenColor = 1
label({ Position = UDim2.fromOffset(16, 92), Size = UDim2.new(1, -32, 0, 18), Text = "ITS MARK", TextColor3 = GOLD, TextScaled = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = founding })
local sigilRow = Instance.new("Frame")
sigilRow.Position = UDim2.fromOffset(16, 112)
sigilRow.Size = UDim2.new(1, -32, 0, 40)
sigilRow.BackgroundTransparency = 1
sigilRow.Parent = founding
local sigilLayout = Instance.new("UIListLayout")
sigilLayout.FillDirection = Enum.FillDirection.Horizontal
sigilLayout.Padding = UDim.new(0, 5)
sigilLayout.Parent = sigilRow
local sigilButtons: { TextButton } = {}
for i, glyph in (Config :: any).CultSigils :: { string } do
	local b: TextButton
	b = button({ Size = UDim2.fromOffset(33, 36), Text = glyph, TextScaled = false, TextSize = 18, BackgroundColor3 = Color3.fromRGB(28, 26, 31), TextColor3 = CREAM }, function()
		chosenSigil = i
		for j, other in sigilButtons do
			other.BackgroundColor3 = j == i and GOLD or Color3.fromRGB(28, 26, 31)
			other.TextColor3 = j == i and BG or CREAM
		end
	end)
	b.Parent = sigilRow
	table.insert(sigilButtons, b)
end

label({ Position = UDim2.fromOffset(16, 160), Size = UDim2.new(1, -32, 0, 18), Text = "ITS COLOR", TextColor3 = GOLD, TextScaled = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = founding })
local colorRow = Instance.new("Frame")
colorRow.Position = UDim2.fromOffset(16, 180)
colorRow.Size = UDim2.new(1, -32, 0, 40)
colorRow.BackgroundTransparency = 1
colorRow.Parent = founding
local colorLayout = Instance.new("UIListLayout")
colorLayout.FillDirection = Enum.FillDirection.Horizontal
colorLayout.Padding = UDim.new(0, 6)
colorLayout.Parent = colorRow
local colorButtons: { TextButton } = {}
for i, swatch in (Config :: any).CultColors :: { Color3 } do
	local b: TextButton
	b = button({ Size = UDim2.fromOffset(44, 36), Text = "", BackgroundColor3 = swatch }, function()
		chosenColor = i
		for j, other in colorButtons do
			local stroke = other:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = j == i and 3 or 0
			end
		end
	end)
	local st = Instance.new("UIStroke")
	st.Color = CREAM
	st.Thickness = i == 1 and 3 or 0
	st.Parent = b
	b.Parent = colorRow
	table.insert(colorButtons, b)
end

local declare = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -52), Size = UDim2.fromOffset(200, 42), Text = "CARVE IT", TextScaled = false, TextSize = 16 }, function()
	local ok, result = pcall(function()
		return Remotes.GetFunction("FoundCult"):InvokeServer(nameBox.Text, chosenSigil, chosenColor)
	end)
	if ok and typeof(result) == "table" then
		local r = result :: any
		if r.ok then
			founding.Visible = false
		elseif typeof(r.message) == "string" then
			nameBox.Text = ""
			nameBox.PlaceholderText = r.message
		end
	end
end)
declare.Parent = founding
local dismiss = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(200, 34), Text = "NOT YET", TextScaled = false, TextSize = 13, BackgroundColor3 = Color3.fromRGB(28, 26, 31), TextColor3 = CREAM }, function()
	founding.Visible = false
end)
dismiss.Parent = founding

Remotes.Get("OpenFounding").OnClientEvent:Connect(function()
	founding.Visible = true
end)

print("[CULT] client ready")
