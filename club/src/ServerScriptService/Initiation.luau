--!strict
-- The way in. Four clues scattered across the grounds each hold one digit of
-- a four-digit code. The code is rolled fresh for every server, so the method
-- can spread and the answer never can. Nothing here tells you it's a puzzle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Rep = require(script.Parent.Rep)

local Initiation = {}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" }

local code = { 0, 0, 0, 0 }
local strikes: { [number]: number } = {}
local lockedUntil: { [number]: number } = {}
local doorsOpen = false
local onInitiated: ((Player) -> ())? = nil
local altarHandler: ((Player, string) -> (boolean, string))? = nil

local function codeString(): string
	return table.concat(code, "")
end

local function whisper(player: Player, text: string)
	Remotes.Get("Notify"):FireClient(player, text, "whisper")
end

-- a prompt that whispers to one person only
local function secretPrompt(host: BasePart, actionText: string, objectText: string, reveal: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
	prompt.Triggered:Connect(reveal)
end

local function openDoors(map: any)
	if doorsOpen then
		return
	end
	doorsOpen = true
	local info = TweenInfo.new(3.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(map.doorL, info, { CFrame = map.doorL.CFrame * CFrame.new(-6.2, 0, 0) }):Play()
	TweenService:Create(map.doorR, info, { CFrame = map.doorR.CFrame * CFrame.new(6.2, 0, 0) }):Play()
	task.delay(45, function()
		local shut = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		TweenService:Create(map.doorL, shut, { CFrame = map.doorL.CFrame }):Play()
		TweenService:Create(map.doorR, shut, { CFrame = map.doorR.CFrame }):Play()
		task.wait(2.4)
		doorsOpen = false
	end)
end

-- The initiate walks in; everyone standing near them at that moment gets a
-- guide bonus. Helping someone solve it is worth as much as solving it.
local function guideBonus(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and Rep.IsInitiated(other) then
			local oc = other.Character
			local oroot = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
			if oroot and (oroot.Position - root.Position).Magnitude < 40 then
				Rep.Award(other, Config.Rep.Guide, "you were there")
			end
		end
	end
end

function Initiation.Init(map: any)
	-- roll tonight's code; the world is then dressed to match it
	local rng = Random.new(os.clock() * 1e6 + os.time())
	code = {
		rng:NextInteger(1, 9), -- torches lit (at least one, or the clue is invisible)
		rng:NextInteger(0, 9),
		rng:NextInteger(1, 9), -- roman numerals have no zero
		rng:NextInteger(0, 9),
	}

	-- clue 1 — light exactly that many of the nine path torches
	for i, torch in map.pathTorches do
		local lit = i <= code[1]
		torch.flame.Transparency = lit and 0 or 1
		torch.light.Enabled = lit
		torch.fire.Enabled = lit
	end

	-- clue 2 — the painting that isn't supposed to exist
	secretPrompt(map.wrongPortrait, "Look closer", "", function(player)
		whisper(player, ("…the second is <b>%d</b>…"):format(code[2]))
	end)

	-- clue 3 — a year that is not a year
	local plate = Instance.new("SurfaceGui")
	plate.Face = Enum.NormalId.Front
	plate.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	plate.PixelsPerStud = 40
	plate.Parent = map.monument
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Michroma
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(150, 128, 82)
	label.Text = "III\n\nMCM · " .. ROMAN[code[3]]
	label.Parent = map.monument and plate

	-- clue 4 — the buried sigil under the marked tree
	local sigilTouched: { [number]: number } = {}
	map.sigil.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if sigilTouched[player.UserId] and now - sigilTouched[player.UserId] < 8 then
			return
		end
		sigilTouched[player.UserId] = now
		task.delay(5, function()
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - map.sigil.Position).Magnitude < 8 then
				whisper(player, ("…the last is <b>%d</b>. four in all, in the order they were carved…"):format(code[4]))
				Rep.ClaimOnce(player, "sigil", "buried", Config.Rep.Sigil, "the buried sigil")
			end
		end)
	end)

	-- the keypad
	local keypadPrompt = Instance.new("ProximityPrompt")
	keypadPrompt.ActionText = "Enter"
	keypadPrompt.ObjectText = ""
	keypadPrompt.HoldDuration = 0.2
	keypadPrompt.MaxActivationDistance = 9
	keypadPrompt.RequiresLineOfSight = false
	keypadPrompt.Parent = map.keypad
	keypadPrompt.Triggered:Connect(function(player)
		Remotes.Get("OpenKeypad"):FireClient(player)
	end)

	local submit = Remotes.GetFunction("SubmitCode")
	submit.OnServerInvoke = function(player: Player, raw: any, context: any): any
		local entered = tostring(raw):gsub("%D", "")
		local now = os.clock()

		-- the altar takes answers too, and they are not the door's code
		if context == "altar" then
			if not altarHandler then
				return { ok = false, message = "Nothing answers." }
			end
			local ok, message = altarHandler(player, entered)
			return { ok = ok, message = message }
		end

		local until_ = lockedUntil[player.UserId]
		if until_ and now < until_ then
			return { ok = false, message = ("The lock is cold. %ds."):format(math.ceil(until_ - now)) }
		end
		if #entered ~= 4 then
			return { ok = false, message = "Four." }
		end
		if entered ~= codeString() then
			strikes[player.UserId] = (strikes[player.UserId] or 0) + 1
			if strikes[player.UserId] >= Config.KeypadStrikes then
				strikes[player.UserId] = 0
				lockedUntil[player.UserId] = now + Config.KeypadLockoutSeconds
				return { ok = false, message = "It stops responding." }
			end
			return { ok = false, message = "Nothing happens." }
		end

		openDoors(map)
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(map.entryPoint))
		end
		if not Rep.IsInitiated(player) then
			guideBonus(player)
			Rep.Award(player, Config.Rep.Initiation, "initiation")
			if onInitiated then
				onInitiated(player)
			end
			Rep.SetInitiated(player)
			Remotes.Get("Initiated"):FireClient(player, player:GetAttribute("Founding"))
			Remotes.Get("Notify"):FireAllClients("Someone solved it. The doors were open for a moment.", "announce")
		end
		return { ok = true, message = "" }
	end

	-- an initiate can always walk back in
	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.ActionText = "Enter"
	returnPrompt.ObjectText = ""
	returnPrompt.HoldDuration = 0.4
	returnPrompt.MaxActivationDistance = 12
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.Parent = map.doorL
	returnPrompt.Triggered:Connect(function(player)
		if Rep.IsInitiated(player) then
			openDoors(map)
			local character = player.Character
			if character then
				character:PivotTo(CFrame.new(map.entryPoint))
			end
		else
			Remotes.Get("Notify"):FireClient(player, "It does not open for you.", "bad")
		end
	end)

	print(("[CULT] tonight's code is %s"):format(codeString()))
end

function Initiation.OnInitiated(callback: (Player) -> ())
	onInitiated = callback
end

function Initiation.SetAltarHandler(callback: (Player, string) -> (boolean, string))
	altarHandler = callback
end

return Initiation
