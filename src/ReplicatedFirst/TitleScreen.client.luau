--!strict
-- The title screen: replaces Roblox's default loading screen with a branded
-- splash — animated logo, drifting cash, rotating tips, and a PLAY button that
-- only unlocks once the world has actually loaded.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GREEN = Color3.fromRGB(63, 191, 74)
local GREEN_DARK = Color3.fromRGB(28, 92, 34)
local YELLOW = Color3.fromRGB(245, 197, 49)
local YELLOW_DARK = Color3.fromRGB(138, 107, 18)
local BLUE = Color3.fromRGB(46, 107, 214)
local BOARD = Color3.fromRGB(26, 36, 24)
local CHALK = Color3.fromRGB(216, 230, 212)

local TIPS = {
	"Recruit students from the Main Hallway — each one earns you money every second.",
	"Lock your homeroom before someone walks in and carries your crew away.",
	"Punch a thief to send your student straight back to their desk.",
	"GOLDEN and RADIOACTIVE students cost more but earn way more.",
	"Fuse 3 copies of the same student into a ★ Star version for triple income.",
	"Pass the pop quiz when the bell rings for cash, aura and a luck boost.",
	"Aura is status. Steal, win quizzes, and defend your crew to climb the ranks.",
	"The richest player in the server wears a crown — robbing them pays extra aura.",
	"Graduate when you can afford it: you lose your crew but keep a permanent multiplier.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "TitleScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- ===== background =====
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = BOARD
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local vignette = Instance.new("UIGradient")
vignette.Rotation = 90
vignette.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 52, 35)),
	ColorSequenceKeypoint.new(0.55, BOARD),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 22, 15)),
})
vignette.Parent = backdrop

-- drifting dollar signs behind the logo
local driftHolder = Instance.new("Frame")
driftHolder.Size = UDim2.fromScale(1, 1)
driftHolder.BackgroundTransparency = 1
driftHolder.ClipsDescendants = true
driftHolder.Parent = backdrop

local rng = Random.new()
local drifters: { { label: TextLabel, speed: number } } = {}
for i = 1, 16 do
	local label = Instance.new("TextLabel")
	label.Text = "$"
	label.Font = Enum.Font.FredokaOne
	label.TextSize = rng:NextInteger(22, 64)
	label.TextColor3 = (i % 3 == 0) and YELLOW or GREEN
	label.TextTransparency = rng:NextNumber(0.55, 0.85)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(80, 80)
	label.Position = UDim2.fromScale(rng:NextNumber(0, 1), rng:NextNumber(0, 1))
	label.Parent = driftHolder
	table.insert(drifters, { label = label, speed = rng:NextNumber(0.012, 0.045) })
end

-- ===== logo =====
local logoHolder = Instance.new("Frame")
logoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
logoHolder.Position = UDim2.fromScale(0.5, 0.38)
logoHolder.Size = UDim2.fromScale(0.9, 0.34)
logoHolder.BackgroundTransparency = 1
logoHolder.Parent = backdrop

local logoScale = Instance.new("UIScale")
logoScale.Scale = 0.7
logoScale.Parent = logoHolder

-- crest: a coin with a $ over crossed rulers
local crest = Instance.new("Frame")
crest.AnchorPoint = Vector2.new(0.5, 1)
crest.Position = UDim2.fromScale(0.5, 0.02)
crest.Size = UDim2.fromOffset(78, 78)
crest.BackgroundColor3 = YELLOW
crest.BorderSizePixel = 0
crest.Parent = logoHolder
local crestCorner = Instance.new("UICorner")
crestCorner.CornerRadius = UDim.new(1, 0)
crestCorner.Parent = crest
local crestStroke = Instance.new("UIStroke")
crestStroke.Color = BOARD
crestStroke.Thickness = 4
crestStroke.Parent = crest
local crestInner = Instance.new("Frame")
crestInner.AnchorPoint = Vector2.new(0.5, 0.5)
crestInner.Position = UDim2.fromScale(0.5, 0.5)
crestInner.Size = UDim2.fromScale(0.76, 0.76)
crestInner.BackgroundColor3 = GREEN
crestInner.BorderSizePixel = 0
crestInner.Parent = crest
local crestInnerCorner = Instance.new("UICorner")
crestInnerCorner.CornerRadius = UDim.new(1, 0)
crestInnerCorner.Parent = crestInner
local crestText = Instance.new("TextLabel")
crestText.Size = UDim2.fromScale(1, 1)
crestText.BackgroundTransparency = 1
crestText.Font = Enum.Font.FredokaOne
crestText.Text = "$"
crestText.TextScaled = true
crestText.TextColor3 = Color3.new(1, 1, 1)
crestText.TextStrokeTransparency = 0.4
crestText.Parent = crestInner

local function wordLabel(text: string, yScale: number, fill: Color3, shadow: Color3): TextLabel
	local shadowLabel = Instance.new("TextLabel")
	shadowLabel.AnchorPoint = Vector2.new(0.5, 0)
	shadowLabel.Position = UDim2.new(0.5, 4, yScale, 5)
	shadowLabel.Size = UDim2.fromScale(1, 0.42)
	shadowLabel.BackgroundTransparency = 1
	shadowLabel.Font = Enum.Font.FredokaOne
	shadowLabel.Text = text
	shadowLabel.TextScaled = true
	shadowLabel.TextColor3 = shadow
	shadowLabel.Parent = logoHolder

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, yScale)
	label.Size = UDim2.fromScale(1, 0.42)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = fill
	label.Parent = logoHolder
	local stroke = Instance.new("UIStroke")
	stroke.Color = BOARD
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

wordLabel("DETENTION", 0.08, YELLOW, YELLOW_DARK)
wordLabel("CHOOSE YOUR PATH", 0.56, CHALK, GREEN_DARK)

local tagline = Instance.new("TextLabel")
tagline.AnchorPoint = Vector2.new(0.5, 0)
tagline.Position = UDim2.fromScale(0.5, 0.95)
tagline.Size = UDim2.fromScale(1, 0.16)
tagline.BackgroundTransparency = 1
tagline.Font = Enum.Font.FredokaOne
tagline.Text = "One school. Endless stories. Choose your path."
tagline.TextScaled = true
tagline.TextColor3 = CHALK
tagline.TextTransparency = 1
tagline.Parent = logoHolder

-- ===== loading bar + tip =====
local barHolder = Instance.new("Frame")
barHolder.AnchorPoint = Vector2.new(0.5, 0.5)
barHolder.Position = UDim2.fromScale(0.5, 0.68)
barHolder.Size = UDim2.new(0.62, 0, 0, 16)
barHolder.BackgroundColor3 = Color3.fromRGB(44, 58, 41)
barHolder.BorderSizePixel = 0
barHolder.Parent = backdrop
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barHolder
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(70, 88, 66)
barStroke.Thickness = 2
barStroke.Parent = barHolder

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = GREEN
barFill.BorderSizePixel = 0
barFill.Parent = barHolder
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

local statusLabel = Instance.new("TextLabel")
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.Position = UDim2.new(0.5, 0, 0, 24)
statusLabel.Size = UDim2.new(1, 0, 0, 22)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.FredokaOne
statusLabel.Text = "Unlocking the front gates..."
statusLabel.TextScaled = true
statusLabel.TextColor3 = Color3.fromRGB(150, 170, 145)
statusLabel.Parent = barHolder

local tipCard = Instance.new("Frame")
tipCard.AnchorPoint = Vector2.new(0.5, 1)
tipCard.Position = UDim2.fromScale(0.5, 0.93)
tipCard.Size = UDim2.new(0.78, 0, 0, 76)
tipCard.BackgroundColor3 = Color3.fromRGB(33, 45, 30)
tipCard.BorderSizePixel = 0
tipCard.Parent = backdrop
local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(0, 14)
tipCorner.Parent = tipCard
local tipStroke = Instance.new("UIStroke")
tipStroke.Color = BLUE
tipStroke.Thickness = 2
tipStroke.Parent = tipCard

local tipHeader = Instance.new("TextLabel")
tipHeader.Position = UDim2.fromOffset(16, 8)
tipHeader.Size = UDim2.new(1, -32, 0, 18)
tipHeader.BackgroundTransparency = 1
tipHeader.Font = Enum.Font.FredokaOne
tipHeader.Text = "SCHOOL RULE"
tipHeader.TextScaled = true
tipHeader.TextXAlignment = Enum.TextXAlignment.Left
tipHeader.TextColor3 = YELLOW
tipHeader.Parent = tipCard

local tipText = Instance.new("TextLabel")
tipText.Position = UDim2.fromOffset(16, 30)
tipText.Size = UDim2.new(1, -32, 0, 38)
tipText.BackgroundTransparency = 1
tipText.Font = Enum.Font.FredokaOne
tipText.Text = TIPS[1]
tipText.TextSize = 17
tipText.TextWrapped = true
tipText.TextXAlignment = Enum.TextXAlignment.Left
tipText.TextYAlignment = Enum.TextYAlignment.Top
tipText.TextColor3 = CHALK
tipText.Parent = tipCard

-- ===== play button (hidden until loaded) =====
local playButton = Instance.new("TextButton")
playButton.AnchorPoint = Vector2.new(0.5, 0.5)
playButton.Position = UDim2.fromScale(0.5, 0.68)
playButton.Size = UDim2.fromOffset(260, 68)
playButton.BackgroundColor3 = GREEN
playButton.Font = Enum.Font.FredokaOne
playButton.Text = "CONTINUE  \u{25B6}"
playButton.TextScaled = true
playButton.TextColor3 = Color3.new(1, 1, 1)
playButton.AutoButtonColor = true
playButton.Visible = false
playButton.Parent = backdrop
local playCorner = Instance.new("UICorner")
playCorner.CornerRadius = UDim.new(0, 16)
playCorner.Parent = playButton
local playStroke = Instance.new("UIStroke")
playStroke.Color = GREEN_DARK
playStroke.Thickness = 4
playStroke.Parent = playButton
local playScale = Instance.new("UIScale")
playScale.Parent = playButton

-- NEW STUDENT: pick your starter before entering
local newButton = Instance.new("TextButton")
newButton.AnchorPoint = Vector2.new(0.5, 0.5)
newButton.Position = UDim2.fromScale(0.5, 0.79)
newButton.Size = UDim2.fromOffset(260, 54)
newButton.BackgroundColor3 = Color3.fromRGB(38, 50, 96)
newButton.Font = Enum.Font.FredokaOne
newButton.Text = "\u{2605}  NEW STUDENT"
newButton.TextScaled = true
newButton.TextColor3 = Color3.new(1, 1, 1)
newButton.AutoButtonColor = true
newButton.Visible = false
newButton.Parent = backdrop
local newCorner = Instance.new("UICorner")
newCorner.CornerRadius = UDim.new(0, 14)
newCorner.Parent = newButton
local newStroke = Instance.new("UIStroke")
newStroke.Color = Color3.fromRGB(255, 196, 60)
newStroke.Thickness = 3
newStroke.Parent = newButton

-- ===== animation =====
local reduceMotion = false

TweenService:Create(logoScale, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
task.delay(0.5, function()
	TweenService:Create(tagline, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
end)

-- gentle drift + logo bob
local elapsed = 0
local driftConn = RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	if reduceMotion then
		return
	end
	for _, drifter in drifters do
		local pos = drifter.label.Position
		local newY = pos.Y.Scale - drifter.speed * dt
		if newY < -0.1 then
			newY = 1.1
			drifter.label.Position = UDim2.fromScale(rng:NextNumber(0, 1), newY)
		else
			drifter.label.Position = UDim2.fromScale(pos.X.Scale, newY)
		end
	end
	logoHolder.Position = UDim2.new(0.5, 0, 0.38, math.sin(elapsed * 1.6) * 6)
end)

-- rotating tips
task.spawn(function()
	local index = 1
	while gui.Parent do
		task.wait(4)
		if not gui.Parent then
			break
		end
		index = index % #TIPS + 1
		TweenService:Create(tipText, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		task.wait(0.25)
		tipText.Text = TIPS[index]
		TweenService:Create(tipText, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	end
end)

-- ===== loading progress =====
local function setProgress(alpha: number)
	TweenService:Create(barFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) }):Play()
end

task.spawn(function()
	setProgress(0.15)
	statusLabel.Text = "Waking up the students..."

	-- wait for the world to replicate
	local started = os.clock()
	while not game:IsLoaded() and os.clock() - started < 25 do
		task.wait(0.1)
	end
	setProgress(0.55)
	statusLabel.Text = "Unlocking the lockers..."

	-- preload what we can see so the first frame is not a texture pop
	local campus = workspace:FindFirstChild("CrumbworthHigh")
	if campus then
		pcall(function()
			ContentProvider:PreloadAsync(campus:GetChildren())
		end)
	end
	setProgress(0.85)
	statusLabel.Text = "Counting the lunch money..."

	task.wait(0.6)
	setProgress(1)
	statusLabel.Text = "Ready!"
	task.wait(0.35)

	barHolder.Visible = false
	playButton.Visible = true
	newButton.Visible = true
	playScale.Scale = 0.8
	TweenService:Create(playScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- idle pulse so it reads as tappable
	task.spawn(function()
		while playButton.Visible and gui.Parent do
			TweenService:Create(playScale, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1.05 }):Play()
			task.wait(0.9)
			TweenService:Create(playScale, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1 }):Play()
			task.wait(0.9)
		end
	end)
end)

-- ===== cinematic intro after PLAY =====
local function runCinematic()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable

	local cine = Instance.new("ScreenGui")
	cine.Name = "Cinematic"
	cine.IgnoreGuiInset = true
	cine.DisplayOrder = 999
	cine.Parent = playerGui

	local function bar(anchorY: number, posY: number): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, posY)
		f.Size = UDim2.fromScale(1, 0.11)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Parent = cine
		return f
	end
	bar(0, 0)
	bar(1, 1)

	local shotLabel = Instance.new("TextLabel")
	shotLabel.AnchorPoint = Vector2.new(0.5, 1)
	shotLabel.Position = UDim2.fromScale(0.5, 0.985)
	shotLabel.Size = UDim2.fromScale(0.9, 0.07)
	shotLabel.BackgroundTransparency = 1
	shotLabel.Font = Enum.Font.FredokaOne
	shotLabel.TextScaled = true
	shotLabel.TextColor3 = YELLOW
	shotLabel.TextStrokeTransparency = 0.5
	shotLabel.Parent = cine

	local skipped = false
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -16, 0, 14)
	skip.Size = UDim2.fromOffset(110, 40)
	skip.BackgroundColor3 = Color3.fromRGB(44, 58, 41)
	skip.Font = Enum.Font.FredokaOne
	skip.Text = "SKIP >>"
	skip.TextScaled = true
	skip.TextColor3 = CHALK
	skip.Parent = cine
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 10)
	skipCorner.Parent = skip
	skip.Activated:Connect(function()
		skipped = true
	end)

	local shots = {
		{
			from = CFrame.lookAt(Vector3.new(-20, 85, 245), Vector3.new(0, 8, 40)),
			to = CFrame.lookAt(Vector3.new(15, 45, 155), Vector3.new(0, 8, 30)),
			dur = 3,
			label = "WELCOME TO DETENTION",
		},
		{
			from = CFrame.lookAt(Vector3.new(-150, 8, 21), Vector3.new(-40, 7, -2)),
			to = CFrame.lookAt(Vector3.new(-10, 8, 21), Vector3.new(100, 7, -2)),
			dur = 3,
			label = "RECRUIT YOUR CREW",
		},
		{
			from = CFrame.lookAt(Vector3.new(70, 24, 195), Vector3.new(0, 5, 128)),
			to = CFrame.lookAt(Vector3.new(-60, 15, 175), Vector3.new(0, 5, 122)),
			dur = 3,
			label = "RULE THE SCHOOL",
		},
	}

	for _, shot in shots do
		if skipped then
			break
		end
		camera.CFrame = shot.from
		shotLabel.Text = shot.label
		shotLabel.TextTransparency = 1
		TweenService:Create(shotLabel, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		local move = TweenService:Create(camera, TweenInfo.new(shot.dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = shot.to })
		move:Play()
		local t0 = os.clock()
		while os.clock() - t0 < shot.dur do
			if skipped then
				move:Cancel()
				break
			end
			task.wait(0.05)
		end
	end

	cine:Destroy()
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local proceeded = false
local function proceed()
	if proceeded then
		return
	end
	proceeded = true
	playButton.Active = false
	newButton.Active = false
	local fade = TweenInfo.new(0.5)
	TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 }):Play()
	for _, descendant in backdrop:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			TweenService:Create(descendant, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif descendant:IsA("Frame") then
			TweenService:Create(descendant, fade, { BackgroundTransparency = 1 }):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, fade, { Transparency = 1 }):Play()
		end
	end
	task.delay(0.55, function()
		driftConn:Disconnect()
		gui:Destroy()
	end)
	runCinematic()
end

playButton.Activated:Connect(proceed)

-- starter picker (shown by NEW STUDENT): two cards, pick dresses you in-game
newButton.Activated:Connect(function()
	if proceeded then
		return
	end
	playButton.Visible = false
	newButton.Visible = false
	local picker = Instance.new("Frame")
	picker.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Position = UDim2.fromScale(0.5, 0.72)
	picker.Size = UDim2.fromOffset(470, 210)
	picker.BackgroundTransparency = 1
	picker.Parent = backdrop
	local cards = {
		{ id = "boy", title = "THE TROUBLEMAKER", emoji = "\u{1F620}", line = "Crest sweater. Bandage.\nBackpack. Attitude.", accent = Color3.fromRGB(64, 96, 200) },
		{ id = "girl", title = "THE REBEL", emoji = "\u{1FAE7}", line = "Plaid skirt. Bubblegum.\nZero patience.", accent = Color3.fromRGB(168, 90, 220) },
	}
	for i, card in cards do
		local cardButton = Instance.new("TextButton")
		cardButton.Position = UDim2.fromOffset((i - 1) * 245, 0)
		cardButton.Size = UDim2.fromOffset(225, 200)
		cardButton.BackgroundColor3 = Color3.fromRGB(24, 34, 26)
		cardButton.Text = ""
		cardButton.AutoButtonColor = true
		cardButton.Parent = picker
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = cardButton
		local stroke = Instance.new("UIStroke")
		stroke.Color = card.accent
		stroke.Thickness = 4
		stroke.Parent = cardButton
		local emoji = Instance.new("TextLabel")
		emoji.Position = UDim2.fromOffset(0, 10)
		emoji.Size = UDim2.new(1, 0, 0, 62)
		emoji.BackgroundTransparency = 1
		emoji.Font = Enum.Font.FredokaOne
		emoji.TextScaled = true
		emoji.Text = card.emoji
		emoji.Parent = cardButton
		local title = Instance.new("TextLabel")
		title.Position = UDim2.fromOffset(8, 80)
		title.Size = UDim2.new(1, -16, 0, 30)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = YELLOW
		title.Text = card.title
		title.Parent = cardButton
		local line = Instance.new("TextLabel")
		line.Position = UDim2.fromOffset(10, 118)
		line.Size = UDim2.new(1, -20, 0, 56)
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.FredokaOne
		line.TextSize = 16
		line.TextWrapped = true
		line.TextColor3 = CHALK
		line.Text = card.line
		line.Parent = cardButton
		cardButton.Activated:Connect(function()
			task.spawn(function()
				local ok = pcall(function()
					local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
					;(Remotes :: any).Get("ChooseCharacter"):FireServer(card.id)
				end)
				if not ok then
					warn("[TitleScreen] could not send starter choice")
				end
			end)
			proceed()
		end)
	end
end)
