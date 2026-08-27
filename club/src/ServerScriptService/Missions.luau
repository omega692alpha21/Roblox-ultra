--!strict
-- Three missions posted daily, the same three on every server so the whole
-- membership is working the same riddles and can talk about them. Never
-- "collect ten coins" — every one of these is a thing you have to notice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Rep = require(script.Parent.Rep)

type Mission = { id: string, no: number, text: string, rep: number }

local Missions: {
	Init: (map: any) -> (),
	AnswerAltar: (player: Player, answer: string) -> (boolean, string),
} = {} :: any

local POOL: { Mission } = {
	{ id = "wrongPainting", no = 17, text = "Find the painting that isn't supposed to exist.", rep = Config.Rep.MissionEasy },
	{ id = "coldCandles", no = 23, text = "Three candles never burn. Find them.", rep = 30 },
	{ id = "countChairs", no = 41, text = "Count the chairs. Tell the altar.", rep = 25 },
	{ id = "reservedSeat", no = 58, text = "Sit where no one sits.", rep = 40 },
	{ id = "ninthFlame", no = 66, text = "The path is guarded. Learn by how many.", rep = 20 },
	{ id = "theRoof", no = 90, text = "The rooftop knows your name.", rep = Config.Rep.MissionHard },
}

local today: { Mission } = {}

local function dayIndex(): number
	return math.floor(os.time() / 86400)
end

local function rollToday()
	local rng = Random.new(dayIndex())
	local pool = table.clone(POOL)
	today = {}
	for _ = 1, 3 do
		if #pool == 0 then
			break
		end
		table.insert(today, table.remove(pool, rng:NextInteger(1, #pool)) :: Mission)
	end
end

local function isToday(id: string): Mission?
	for _, mission in today do
		if mission.id == id then
			return mission
		end
	end
	return nil
end

local function complete(player: Player, id: string): boolean
	local mission = isToday(id)
	if not mission then
		return false
	end
	if not Rep.IsInitiated(player) then
		return false
	end
	return Rep.ClaimOnce(player, "mission", id, mission.rep, ("mission %03d"):format(mission.no))
end

local function boardText(): string
	local lines = { "" }
	for _, mission in today do
		table.insert(lines, ("MISSION %03d\n%s\n"):format(mission.no, mission.text))
	end
	return table.concat(lines, "\n")
end

Missions.Init = function(map: any)
	rollToday()

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = map.missionBoard
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.9)
	label.Position = UDim2.fromScale(0.05, 0.05)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Michroma
	label.TextSize = 22
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = Color3.fromRGB(206, 178, 116)
	label.Text = boardText()
	label.Parent = gui

	task.spawn(function()
		local day = dayIndex()
		while true do
			task.wait(120)
			if dayIndex() ~= day then
				day = dayIndex()
				rollToday()
				label.Text = boardText()
				Remotes.Get("Notify"):FireAllClients("The board has changed.", "announce")
			end
		end
	end)

	Remotes.GetFunction("GetMissions").OnServerInvoke = function(player: Player): any
		local record = Rep.Get(player)
		local out = {}
		for _, mission in today do
			table.insert(out, {
				no = mission.no,
				text = mission.text,
				rep = mission.rep,
				done = record.missions[mission.id] == dayIndex(),
			})
		end
		return out
	end

	-- mission 017: the painting that isn't supposed to exist
	local paintingPrompt = Instance.new("ProximityPrompt")
	paintingPrompt.ActionText = "Straighten it"
	paintingPrompt.ObjectText = ""
	paintingPrompt.HoldDuration = 1
	paintingPrompt.MaxActivationDistance = 10
	paintingPrompt.RequiresLineOfSight = false
	paintingPrompt.Parent = map.wrongPortrait
	paintingPrompt.Triggered:Connect(function(player)
		if complete(player, "wrongPainting") then
			Remotes.Get("Notify"):FireClient(player, "It was never crooked. You were.", "good")
		end
	end)

	-- mission 023: three candles that never burn
	local found: { [number]: { [string]: boolean } } = {}
	for _, candle in map.folder:GetDescendants() do
		if candle:IsA("BasePart") and candle.Name == "ColdCandle" then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Touch the wick"
			prompt.ObjectText = ""
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 7
			prompt.RequiresLineOfSight = false
			prompt.Parent = candle
			local groupKey = ("%d_%d"):format(math.floor(candle.Position.X / 10), math.floor(candle.Position.Z / 10))
			prompt.Triggered:Connect(function(player)
				local mine = found[player.UserId]
				if not mine then
					mine = {}
					found[player.UserId] = mine
				end
				if mine[groupKey] then
					return
				end
				mine[groupKey] = true
				local count = 0
				for _ in mine do
					count += 1
				end
				if count >= 3 then
					if complete(player, "coldCandles") then
						Remotes.Get("Notify"):FireClient(player, "Three. Cold as the day they were set.", "good")
					end
				else
					Remotes.Get("Notify"):FireClient(player, ("%d of three."):format(count), "whisper")
				end
			end)
		end
	end

	-- missions 041 and 066: answers spoken to the altar
	local altarPrompt = Instance.new("ProximityPrompt")
	altarPrompt.ActionText = "Speak"
	altarPrompt.ObjectText = ""
	altarPrompt.HoldDuration = 0.4
	altarPrompt.MaxActivationDistance = 10
	altarPrompt.RequiresLineOfSight = false
	altarPrompt.Parent = map.altar
	altarPrompt.Triggered:Connect(function(player)
		Remotes.Get("OpenKeypad"):FireClient(player, "altar")
	end)

	local litTorches = 0
	for _, torch in map.pathTorches do
		if torch.light.Enabled then
			litTorches += 1
		end
	end
	Missions.AnswerAltar = function(player: Player, answer: string): (boolean, string)
		local n = tonumber(answer)
		if n == 12 and complete(player, "countChairs") then
			return true, "Twelve. One of them is not for you."
		end
		if n == litTorches and complete(player, "ninthFlame") then
			return true, "That is how many burned tonight."
		end
		return false, "The flame does not move."
	end

	-- mission 058: the twelfth chair
	local reserved = map.folder:FindFirstChild("ReservedSeat") :: Seat?
	if reserved then
		reserved:GetPropertyChangedSignal("Occupant"):Connect(function()
			local occupant = reserved.Occupant
			local character = occupant and occupant.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if player and complete(player, "reservedSeat") then
				Remotes.Get("Notify"):FireClient(player, "You are sitting in someone's chair.", "good")
			end
		end)
	end

end

-- replaced in Init once the map exists
Missions.AnswerAltar = function(_player: Player, _answer: string): (boolean, string)
	return false, "Nothing answers."
end

return Missions
