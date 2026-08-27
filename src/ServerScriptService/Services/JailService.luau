--!strict
-- DETENTION — the room that lives up to the game's name.
--
-- Get caught after curfew and you are locked in the detention hall for a real
-- sentence: a countdown, barred doors, and a teleport back to your bench if
-- you try to walk out. The Jail Pass is the only way to skip it — buy it and
-- you stroll out of any sentence, forever.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Products = require(ReplicatedStorage.Config.Products)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)

local JailService = {}

-- the detention hall, east wing (matches MapService's floor plan)
local CELL_CENTER = Vector3.new(204, 0, 35)
local CELL_HALF_X, CELL_HALF_Z = 20, 29

local sentences: { [Player]: number } = {} -- player -> os.clock() release time
local bars: { BasePart } = {}

local function hasPass(player: Player): boolean
	local id = Products.GamePasses.JailPass.id
	if id == 0 then
		return false
	end
	if player:GetAttribute("HasJailPass") == true then
		return true
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	if ok and owns then
		player:SetAttribute("HasJailPass", true)
		return true
	end
	return false
end

-- Hall passes are consumable and stack. Good students earn them (quizzes,
-- missions, quests); anyone can buy a book of them. Getting caught spends one
-- instead of sending you down.
function JailService.HallPasses(player: Player): number
	return tonumber(player:GetAttribute("HallPasses")) or 0
end

function JailService.GrantHallPass(player: Player, count: number?, reason: string?)
	local n = count or 1
	local total = JailService.HallPasses(player) + n
	player:SetAttribute("HallPasses", total)
	local profile = DataService.Get(player)
	if profile then
		(profile :: any).hallPasses = total
	end
	Remotes.Get("Notify"):FireClient(
		player,
		("🎟️ %s Hall pass%s earned%s — you now have %d."):format(
			n > 1 and ("+" .. n) or "+1",
			n > 1 and "es" or "",
			reason and (" " .. reason) or "",
			total
		),
		"good"
	)
end

-- Spend one if they have it. Returns true when the pass covered them.
function JailService.SpendHallPass(player: Player): boolean
	local have = JailService.HallPasses(player)
	if have <= 0 then
		return false
	end
	local left = have - 1
	player:SetAttribute("HallPasses", left)
	local profile = DataService.Get(player)
	if profile then
		(profile :: any).hallPasses = left
	end
	Remotes.Get("Notify"):FireClient(
		player,
		("🎟️ You flash your HALL PASS. The prefect waves you on. %d left."):format(left),
		"good"
	)
	return true
end

local function benchSpot(): Vector3
	return CELL_CENTER + Vector3.new(math.random(-12, 12), 4, math.random(-16, 16))
end

local function release(player: Player, reason: string)
	if not sentences[player] then
		return
	end
	sentences[player] = nil
	player:SetAttribute("DetentionUntil", nil)
	Remotes.Get("JailState"):FireClient(player, 0, false)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end
	-- put them back out front rather than leaving them stuck in the cell
	if character then
		character:PivotTo(CFrame.new(20, 4, 152))
	end
	Remotes.Get("Notify"):FireClient(player, reason, "info")
end

-- Lock a player in for `seconds`. Returns the actual sentence served.
function JailService.Jail(player: Player, seconds: number?): number
	local sentence = seconds or GameConfig.DetentionSeconds
	-- a hall pass is spent first: it is the thing a good student actually has
	if JailService.SpendHallPass(player) then
		return 0
	end
	if hasPass(player) then
		-- pass holders never serve: they are escorted in and walk right out
		Remotes.Get("Notify"):FireClient(player, "🔓 Jail Pass — you walk straight back out.", "good")
		return 0
	end
	sentences[player] = os.clock() + sentence
	player:SetAttribute("DetentionUntil", os.clock() + sentence)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(benchSpot()))
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 8 -- you can shuffle around the cell, not run
	end
	Remotes.Get("JailState"):FireClient(player, sentence, Products.GamePasses.JailPass.id ~= 0)
	return sentence
end

function JailService.IsJailed(player: Player): boolean
	return sentences[player] ~= nil
end

-- The bars: a physical cage that only exists while someone is serving.
local function buildBars(folder: Instance)
	local doorway = CFrame.new(204, 0, 64) -- the detention hall's door onto the corridor
	for i = 0, 6 do
		local bar = Instance.new("Part")
		bar.Name = "DetentionBar"
		bar.Anchored = true
		bar.CanCollide = true
		bar.Size = Vector3.new(0.45, 13, 0.45)
		bar.CFrame = doorway * CFrame.new(-6 + i * 2, 6.5, 0)
		bar.Color = Color3.fromRGB(58, 60, 66)
		bar.Material = Enum.Material.Metal
		bar.Parent = folder
		table.insert(bars, bar)
	end
	local rail = Instance.new("Part")
	rail.Name = "DetentionBar"
	rail.Anchored = true
	rail.CanCollide = true
	rail.Size = Vector3.new(14, 0.5, 0.5)
	rail.CFrame = doorway * CFrame.new(0, 12.6, 0)
	rail.Color = Color3.fromRGB(58, 60, 66)
	rail.Material = Enum.Material.Metal
	rail.Parent = folder
	table.insert(bars, rail)
end

function JailService.Init(map: { folder: Instance })
	buildBars(map.folder)

	Remotes.Get("RequestJailSkip").OnServerEvent:Connect(function(player)
		if not sentences[player] then
			return
		end
		if hasPass(player) then
			release(player, "🔓 Jail Pass — sentence skipped. Try not to get caught next time.")
		elseif Products.GamePasses.JailPass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, Products.GamePasses.JailPass.id)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Products.GamePasses.JailPass.id then
			player:SetAttribute("HasJailPass", true)
			if sentences[player] then
				release(player, "🔓 Jail Pass unlocked — the door swings open.")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sentences[player] = nil
	end)

	-- carry saved hall passes onto the player attribute when data loads
	require(script.Parent.Parent.Signals).ProfileLoaded:Connect(function(player, profile)
		player:SetAttribute("HallPasses", tonumber((profile :: any).hallPasses) or 0)
	end)

	-- serve the sentence: tick the countdown and keep escapees inside
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, until_ in sentences do
				if not player.Parent then
					sentences[player] = nil
					continue
				end
				local left = math.max(0, math.ceil(until_ - now))
				if left <= 0 then
					release(player, "Detention's over. Walk it off.")
					continue
				end
				Remotes.Get("JailState"):FireClient(player, left, Products.GamePasses.JailPass.id ~= 0)
				-- no walking out: anyone past the cell walls goes back to a bench
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if character and root then
					local offset = root.Position - CELL_CENTER
					if math.abs(offset.X) > CELL_HALF_X or math.abs(offset.Z) > CELL_HALF_Z or offset.Y > 20 then
						character:PivotTo(CFrame.new(benchSpot()))
						Remotes.Get("Notify"):FireClient(player, "Sit down. You're not going anywhere.", "bad")
					end
				end
			end
		end
	end)
end

return JailService
