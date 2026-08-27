--!strict
-- MILLIONS CLUB — client: tier chip, the membership ladder, profile editor,
-- member directory, toasts and global announcements.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Club"):WaitForChild("ClubConfig"))
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(212, 175, 85)
local GOLD_BRIGHT = Color3.fromRGB(255, 208, 110)
local BG = Color3.fromRGB(18, 16, 20)
local CREAM = Color3.fromRGB(240, 234, 222)

local gui = Instance.new("ScreenGui")
gui.Name = "RobesUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	local out = ""
	local count = 0
	for i = #s, 1, -1 do
		out = s:sub(i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return out
end

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

local function framed(size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = BG
	f.BackgroundTransparency = 0.08
	f.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = f
	return f
end

-- ------------------------------------------------------------------- chip ---
local chip = framed(UDim2.fromOffset(148, 26), UDim2.new(0, 8, 0, 6), Vector2.new(0, 0))
chip.BackgroundTransparency = 0.25
local chipLabel = label({ Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), Text = "ROBES", TextColor3 = GOLD, TextScaled = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })

task.spawn(function()
	while true do
		local tier = tostring(player:GetAttribute("Tier") or "GUEST")
		local seat = player:GetAttribute("Seat")
		local count = tonumber(ReplicatedStorage:GetAttribute("SeatCount")) or 0
		local price = tonumber(ReplicatedStorage:GetAttribute("SeatPrice")) or 0
		if tier ~= "GUEST" then
			chipLabel.Text = if typeof(seat) == "number"
				then ("◆ %s · №%d/%d"):format(tier, seat, Config.FoundingSeats)
				else "◆ " .. tier
		else
			chipLabel.Text = if count >= Config.FoundingSeats
				then "ROBES · CLOSED"
				else ("ROBE №%d · %s R$"):format(count + 1, fmt(price))
		end
		task.wait(2)
	end
end)

-- ----------------------------------------------------------------- toasts ---
local toastY = -30
Remotes.Get("Notify").OnClientEvent:Connect(function(message, kind)
	if typeof(message) ~= "string" then
		return
	end
	local isAnnounce = kind == "announce"
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, toastY)
	toast.Size = UDim2.fromOffset(isAnnounce and 520 or 430, isAnnounce and 56 or 46)
	toast.BackgroundColor3 = BG
	toast.BackgroundTransparency = 0.08
	toast.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = if kind == "bad" then Color3.fromRGB(180, 60, 60) elseif isAnnounce then GOLD_BRIGHT else GOLD
	stroke.Thickness = isAnnounce and 3 or 2
	stroke.Parent = toast
	label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Text = message,
		TextScaled = false,
		TextSize = isAnnounce and 18 or 15,
		TextWrapped = true,
		TextColor3 = isAnnounce and GOLD_BRIGHT or CREAM,
		Parent = toast,
	})
	if isAnnounce then
		TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 6, true), { Thickness = 5 }):Play()
	end
	task.delay(isAnnounce and 7 or 4.5, function()
		toast:Destroy()
	end)
end)

-- ----------------------------------------------------------- the ladder ---
local ladder = framed(UDim2.fromOffset(460, 430), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
ladder.Visible = false
label({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 30), Text = "THE LADDER", TextColor3 = GOLD, Parent = ladder })
label({
	Position = UDim2.fromOffset(14, 42),
	Size = UDim2.new(1, -28, 0, 34),
	Text = "100 robes. Ever. Then four robes above —\neach rarer, higher, and harder to ignore.",
	TextScaled = false,
	TextSize = 13,
	TextWrapped = true,
	TextTransparency = 0.2,
	Parent = ladder,
})

local rows = Instance.new("Frame")
rows.Position = UDim2.fromOffset(14, 84)
rows.Size = UDim2.new(1, -28, 1, -140)
rows.BackgroundTransparency = 1
rows.Parent = ladder
local rowLayout = Instance.new("UIListLayout")
rowLayout.Padding = UDim.new(0, 8)
rowLayout.Parent = rows

local function ladderRow(order: number, name: string, price: string, detail: string, tierArg: string)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = Color3.fromRGB(28, 26, 32)
	row.Parent = rows
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row
	label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.5, -12, 0, 22), Text = name, TextColor3 = GOLD_BRIGHT, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 16, Parent = row })
	label({ Position = UDim2.fromOffset(12, 27), Size = UDim2.new(0.6, -12, 0, 18), Text = detail, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 11, TextTransparency = 0.25, Parent = row })
	local b = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 34),
		Text = price,
		TextScaled = false,
		TextSize = 13,
	}, function()
		Remotes.Get("RequestJoin"):FireServer(tierArg)
	end)
	b.Parent = row
end

local function refreshLadder()
	for _, child in rows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local count = tonumber(ReplicatedStorage:GetAttribute("SeatCount")) or 0
	local price = tonumber(ReplicatedStorage:GetAttribute("SeatPrice")) or 0
	if count >= Config.FoundingSeats then
		ladderRow(1, "THE ROBE", "GRANTED", "All 100 robes granted. Forever.", "")
	else
		ladderRow(1, ("THE ROBE · № %d"):format(count + 1), fmt(price) .. " R$", ("%d of %d robes remain"):format(Config.FoundingSeats - count, Config.FoundingSeats), "")
	end
	local details: { [string]: string } = {
		GOLD = "Gold cloth + the Gold Chamber",
		PLATINUM = "Platinum cloth + the Platinum Chamber",
		BLACK = "True black + the Black Chamber",
		CROWN = "The luminous robe. One will ever exist.",
	}
	local order = 2
	for _, tier in Config.Tiers do
		if tier.price > 0 then
			ladderRow(order, tier.name, fmt(tier.price) .. " R$", details[tier.name] or "", tier.name)
			order += 1
		end
	end
end

button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(120, 32),
	Text = "CLOSE",
	TextScaled = false,
	TextSize = 13,
	BackgroundColor3 = Color3.fromRGB(40, 38, 44),
	TextColor3 = CREAM,
}, function()
	ladder.Visible = false
end).Parent = ladder

-- ------------------------------------------------------------- profile ---
local panel = framed(UDim2.fromOffset(430, 380), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
panel.Visible = false
label({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28), Text = "YOUR MEMBER PROFILE", TextColor3 = GOLD, Parent = panel })

local myInterests: { [string]: boolean } = {}
local myLookingFor: { [string]: boolean } = {}

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

tagPicker(panel, "INTERESTS", Config.Interests, myInterests, 46)
tagPicker(panel, "LOOKING FOR", Config.LookingFor, myLookingFor, 172)

button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, -70, 1, -12),
	Size = UDim2.fromOffset(120, 34),
	Text = "SAVE",
	TextScaled = false,
	TextSize = 14,
}, function()
	local interests: { string } = {}
	local looking: { string } = {}
	for tag in myInterests do
		table.insert(interests, tag)
	end
	for tag in myLookingFor do
		table.insert(looking, tag)
	end
	Remotes.Get("SetProfile"):FireServer(interests, looking)
	panel.Visible = false
end).Parent = panel
button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 70, 1, -12),
	Size = UDim2.fromOffset(120, 34),
	Text = "CLOSE",
	TextScaled = false,
	TextSize = 14,
	BackgroundColor3 = Color3.fromRGB(40, 38, 44),
	TextColor3 = CREAM,
}, function()
	panel.Visible = false
end).Parent = panel

-- ----------------------------------------------------------- directory ---
local directory = framed(UDim2.fromOffset(460, 430), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
directory.Visible = false
label({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28), Text = "MEMBER DIRECTORY", TextColor3 = GOLD, Parent = directory })
local dirScroll = Instance.new("ScrollingFrame")
dirScroll.Position = UDim2.fromOffset(14, 46)
dirScroll.Size = UDim2.new(1, -28, 1, -104)
dirScroll.BackgroundTransparency = 1
dirScroll.BorderSizePixel = 0
dirScroll.CanvasSize = UDim2.fromOffset(0, 0)
dirScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
dirScroll.ScrollBarThickness = 4
dirScroll.Parent = directory
local dirLayout = Instance.new("UIListLayout")
dirLayout.Padding = UDim.new(0, 8)
dirLayout.Parent = dirScroll

local function refreshDirectory()
	for _, child in dirScroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local ok, entries = pcall(function()
		return Remotes.GetFunction("GetDirectory"):InvokeServer()
	end)
	if not ok or typeof(entries) ~= "table" then
		return
	end
	for _, entry in entries :: { any } do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -8, 0, 62)
		card.BackgroundColor3 = Color3.fromRGB(28, 26, 32)
		card.Parent = dirScroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card
		label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), Text = tostring(entry.name), TextColor3 = GOLD_BRIGHT, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, TextSize = 15, Parent = card })
		label({
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -24, 0, 30),
			Text = table.concat(entry.interests or {}, " · ") .. "\nLooking for: " .. table.concat(entry.lookingFor or {}, ", "),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 11,
			TextWrapped = true,
			TextTransparency = 0.2,
			Parent = card,
		})
	end
end

button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(120, 32),
	Text = "CLOSE",
	TextScaled = false,
	TextSize = 13,
	BackgroundColor3 = Color3.fromRGB(40, 38, 44),
	TextColor3 = CREAM,
}, function()
	directory.Visible = false
end).Parent = directory

-- --------------------------------------------------------------- nav ---
local nav = Instance.new("Frame")
nav.AnchorPoint = Vector2.new(1, 0.5)
nav.Position = UDim2.new(1, -10, 0.5, -30)
nav.Size = UDim2.fromOffset(120, 160)
nav.BackgroundTransparency = 1
nav.Visible = false
nav.Parent = gui
local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = nav

local menuToggle = button({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 80),
	Size = UDim2.fromOffset(52, 52),
	Text = "☰",
	TextScaled = false,
	TextSize = 24,
}, function()
	nav.Visible = not nav.Visible
	if not nav.Visible then
		ladder.Visible = false
		panel.Visible = false
		directory.Visible = false
	end
end)
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = menuToggle
end
menuToggle.Parent = gui

local function navButton(text: string, onClick: () -> ())
	local b = button({ Size = UDim2.new(1, 0, 0, 40), Text = text, TextScaled = false, TextSize = 13 }, onClick)
	b.BackgroundTransparency = 0.06
	b.Parent = nav
end

navButton("THE LADDER", function()
	refreshLadder()
	ladder.Visible = not ladder.Visible
	panel.Visible = false
	directory.Visible = false
end)

navButton("PROFILE", function()
	panel.Visible = not panel.Visible
	ladder.Visible = false
	directory.Visible = false
end)

navButton("DIRECTORY", function()
	refreshDirectory()
	directory.Visible = not directory.Visible
	ladder.Visible = false
	panel.Visible = false
end)

-- ------------------------------------------- own robe out of the way ---
-- Your own robe, its tag and any effects are hidden from your own camera
-- only, via local property sets that nothing overwrites. Others see you.
task.spawn(function()
	while true do
		local character = player.Character
		local robe = character and character:FindFirstChild("RobeForm")
		if robe then
			for _, p in (robe :: Model):GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					p.Transparency = 1
				elseif p:IsA("BillboardGui") and p.Enabled then
					p.Enabled = false
				elseif (p:IsA("Sparkles") or p:IsA("ParticleEmitter") or p:IsA("Fire") or p:IsA("PointLight")) and (p :: any).Enabled then
					(p :: any).Enabled = false
				end
			end
		end
		task.wait(0.4)
	end
end)

print("[ROBES] client ready")
