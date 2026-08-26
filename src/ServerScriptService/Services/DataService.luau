--!strict
-- Player data persistence. UpdateAsync session locking, retries with backoff,
-- autosave, BindToClose. If a load ultimately fails the player stays in a
-- "not loaded" state where nothing can earn, spend, or save (so a real save
-- is never overwritten with the blank template).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Signals = require(script.Parent.Parent.Signals)

local STORE_NAME = "PlayerData_v1"
local LOCK_STALE_SECONDS = 600
local MAX_PURCHASE_IDS = 50

export type Profile = {
	cash: number,
	totalEarned: number,
	aura: number,
	grade: number,
	clique: string?,
	crew: { { uid: string, id: string, mut: string?, star: boolean? } },
	purchaseIds: { string },
	loginStreak: number,
	lastLoginDay: number,
	lastSpinDay: number,
	spinTokens: number,
	lastSeen: number,
	lastIncome: number,
	social: { [string]: boolean },
	missions: { [string]: number }, -- mission giver id -> completed count
	rep: { [string]: number }, -- reputation tracks: popular/smart/athletic/creative/troublemaker
}

local function template(): Profile
	return {
		cash = GameConfig.StarterCash,
		totalEarned = 0,
		aura = 0,
		grade = 0,
		clique = nil,
		crew = {},
		purchaseIds = {},
		loginStreak = 0,
		lastLoginDay = 0,
		lastSpinDay = 0,
		spinTokens = 0,
		lastSeen = 0,
		lastIncome = 0,
		social = {},
		missions = {},
		rep = {},
	}
end

local DataService = {}

local store: DataStore? = nil
local sessionId = HttpService:GenerateGUID(false)
local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable:", result)
	end
	return store
end

local function withRetries<T>(label: string, fn: () -> T): (boolean, T?)
	local delaySeconds = 1
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} attempt {attempt} failed: {result}`)
		if attempt < 3 then
			task.wait(delaySeconds)
			delaySeconds *= 2
		end
	end
	return false, nil
end

-- Fill in any fields added after a profile was first saved.
local function reconcile(data: any): Profile
	local base = template()
	if type(data) ~= "table" then
		return base
	end
	for k, v in base :: any do
		if (data :: any)[k] == nil then
			(data :: any)[k] = v
		end
	end
	return data :: Profile
end

local function key(userId: number): string
	return "u_" .. tostring(userId)
end

function DataService.Get(player: Player): Profile?
	return loaded[player] and profiles[player] or nil
end

function DataService.IsLoaded(player: Player): boolean
	return loaded[player] == true
end

local function saveProfile(player: Player, releasingLock: boolean): boolean
	local profile = profiles[player]
	if not profile or not loaded[player] then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end
	profile.lastSeen = os.time()
	local ok = withRetries("save " .. player.Name, function()
		ds:UpdateAsync(key(player.UserId), function(old)
			local record = if type(old) == "table" then old else {}
			record.data = profile
			if releasingLock then
				record.lock = nil
			else
				record.lock = { id = sessionId, t = os.time() }
			end
			return record
		end)
		return true
	end)
	return ok
end

-- Force-save (used by MonetizationService before granting a purchase).
function DataService.ForceSave(player: Player): boolean
	return saveProfile(player, false)
end

local function loadProfile(player: Player)
	local ds = getStore()
	if not ds then
		-- Studio without API access: run on a volatile template so the game is testable.
		if RunService:IsStudio() then
			warn("[DataService] Studio without DataStore access — using volatile profile for " .. player.Name)
			profiles[player] = template()
			loaded[player] = true
			player:SetAttribute("DataLoaded", true)
			Signals.ProfileLoaded:Fire(player, profiles[player])
		else
			player:SetAttribute("DataLoaded", false)
		end
		return
	end

	local claimed: Profile? = nil
	local ok = withRetries("load " .. player.Name, function()
		local denied = false
		ds:UpdateAsync(key(player.UserId), function(old)
			local record = if type(old) == "table" then old else {}
			local lock = record.lock
			if lock and lock.id ~= sessionId and os.time() - (lock.t or 0) < LOCK_STALE_SECONDS then
				denied = true
				return nil -- abort the write, another server holds the lock
			end
			record.lock = { id = sessionId, t = os.time() }
			record.data = reconcile(record.data)
			claimed = record.data
			return record
		end)
		if denied then
			error("session locked by another server")
		end
		return true
	end)

	if not ok or not claimed then
		player:SetAttribute("DataLoaded", false)
		warn(`[DataService] could not load data for {player.Name}; play disabled this session`)
		return
	end
	if not player.Parent then
		-- player left mid-load: release the lock
		withRetries("release " .. player.Name, function()
			ds:UpdateAsync(key(player.UserId), function(old)
				local record = if type(old) == "table" then old else {}
				record.lock = nil
				return record
			end)
			return true
		end)
		return
	end

	profiles[player] = claimed :: Profile
	loaded[player] = true
	player:SetAttribute("DataLoaded", true)
	Signals.ProfileLoaded:Fire(player, claimed)
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("DataLoaded", false)
		task.spawn(loadProfile, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if loaded[player] then
			saveProfile(player, true)
		end
		profiles[player] = nil
		loaded[player] = nil
	end)

	-- autosave
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for player in profiles do
				if loaded[player] then
					task.spawn(saveProfile, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local saving = 0
		for player in profiles do
			if loaded[player] then
				saving += 1
				task.spawn(function()
					saveProfile(player, true)
					saving -= 1
				end)
			end
		end
		while saving > 0 do
			task.wait(0.1)
		end
	end)
end

-- Purchase-id bookkeeping for idempotent receipt processing.
function DataService.HasPurchase(player: Player, purchaseId: string): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	return table.find(profile.purchaseIds, purchaseId) ~= nil
end

function DataService.RecordPurchase(player: Player, purchaseId: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	table.insert(profile.purchaseIds, purchaseId)
	while #profile.purchaseIds > MAX_PURCHASE_IDS do
		table.remove(profile.purchaseIds, 1)
	end
end

return DataService
