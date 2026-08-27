--!strict
-- REP is the only currency here, and it cannot be bought. It buys rank, rank
-- opens doors, and the doors are the game. Persisted per player.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)

local Rep = {}

type Record = { rep: number, initiated: boolean, sigils: { [string]: boolean }, missions: { [string]: number }, founding: number? }

local cache: { [number]: Record } = {}
local dirty: { [number]: boolean } = {}

local function store(): DataStore?
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("CultRep")
	end)
	return ok and ds or nil
end

local function blank(): Record
	return { rep = 0, initiated = false, sigils = {}, missions = {} }
end

local function key(userId: number): string
	return "p_" .. userId
end

function Rep.Get(player: Player): Record
	return cache[player.UserId] or blank()
end

local function push(player: Player, reason: string?)
	local record = Rep.Get(player)
	local rank = Config.RankFor(record.rep)
	player:SetAttribute("Rep", record.rep)
	player:SetAttribute("Rank", rank.name)
	player:SetAttribute("Initiated", record.initiated)
	Remotes.Get("RepChanged"):FireClient(player, record.rep, rank.name, reason or "")
end

function Rep.Load(player: Player)
	local record = blank()
	local ds = store()
	if ds then
		local ok, saved = pcall(function()
			return ds:GetAsync(key(player.UserId))
		end)
		if ok and typeof(saved) == "table" then
			local s = saved :: any
			record.rep = tonumber(s.rep) or 0
			record.initiated = s.initiated == true
			record.sigils = typeof(s.sigils) == "table" and s.sigils or {}
			record.missions = typeof(s.missions) == "table" and s.missions or {}
			record.founding = tonumber(s.founding)
		end
	end
	cache[player.UserId] = record
	push(player)
end

function Rep.Save(player: Player)
	local record = cache[player.UserId]
	if not record or not dirty[player.UserId] then
		return
	end
	local ds = store()
	if not ds then
		return
	end
	pcall(function()
		ds:SetAsync(key(player.UserId), record)
	end)
	dirty[player.UserId] = nil
end

-- Award rep. Returns the new total; announces a rank change to everyone.
function Rep.Award(player: Player, amount: number, reason: string): number
	local record = cache[player.UserId]
	if not record or amount <= 0 then
		return record and record.rep or 0
	end
	local before = Config.RankFor(record.rep).name
	record.rep += amount
	dirty[player.UserId] = true
	local after = Config.RankFor(record.rep)
	push(player, ("+%d REP · %s"):format(amount, reason))
	if after.name ~= before then
		Remotes.Get("Notify"):FireAllClients(
			("A hooded figure rises to %s."):format(after.name),
			"announce"
		)
		Remotes.Get("Notify"):FireClient(player, ("You are %s now. %s is open to you."):format(after.name, after.unlocks), "good")
	end
	return record.rep
end

function Rep.SetInitiated(player: Player, foundingSeat: number?)
	local record = cache[player.UserId]
	if not record then
		return
	end
	record.initiated = true
	record.founding = foundingSeat or record.founding
	dirty[player.UserId] = true
	push(player)
	Rep.Save(player)
end

function Rep.IsInitiated(player: Player): boolean
	local record = cache[player.UserId]
	return record ~= nil and record.initiated
end

-- one-time claims (sigils found, missions completed)
function Rep.ClaimOnce(player: Player, bucket: string, id: string, amount: number, reason: string): boolean
	local record = cache[player.UserId]
	if not record then
		return false
	end
	if bucket == "sigil" then
		if record.sigils[id] then
			return false
		end
		record.sigils[id] = true
	else
		local today = math.floor(os.time() / 86400)
		if record.missions[id] == today then
			return false
		end
		record.missions[id] = today
	end
	dirty[player.UserId] = true
	Rep.Award(player, amount, reason)
	return true
end

function Rep.RankIndexOf(player: Player): number
	return Config.RankIndex(tostring(player:GetAttribute("Rank") or "INITIATE"))
end

function Rep.Init()
	local function onAdded(player: Player)
		Rep.Load(player)
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Rep.Save(player)
		cache[player.UserId] = nil
		dirty[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				Rep.Save(player)
			end
		end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			Rep.Save(player)
		end
	end)
end

return Rep
