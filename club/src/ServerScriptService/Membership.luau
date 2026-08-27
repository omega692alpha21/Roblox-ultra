--!strict
-- The product: 100 memberships, ever, priced upward by batch — then tier
-- upgrades that climb the pyramid. Ownership is a game pass; the seat number
-- is claimed atomically across all servers and closes forever at 100.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)

local Membership = {}

local ROSTER_KEY = "seats_v1"
local TOPIC = "MC_EVENTS"
local roster: { number } = {}

local function store(): DataStore?
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("MillionsClub")
	end)
	return ok and ds or nil
end

local function publishCount()
	ReplicatedStorage:SetAttribute("SeatCount", #roster)
	local batch = Config.ActiveBatch(#roster)
	ReplicatedStorage:SetAttribute("SeatPrice", batch and batch.price or 0)
end

local function broadcast(text: string)
	Remotes.Get("Notify"):FireAllClients(text, "announce")
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { j = game.JobId, t = text })
	end)
end

local function loadRoster()
	local ds = store()
	if not ds then
		return
	end
	pcall(function()
		local saved = ds:GetAsync(ROSTER_KEY)
		if typeof(saved) == "table" then
			roster = saved :: { number }
		end
	end)
	publishCount()
end

local function claimSeat(userId: number): number?
	local ds = store()
	if not ds then
		return nil
	end
	local seat: number? = nil
	pcall(function()
		ds:UpdateAsync(ROSTER_KEY, function(old)
			local list: { number } = typeof(old) == "table" and old :: { number } or {}
			for i, id in list do
				if id == userId then
					seat = i
					return list
				end
			end
			if #list >= Config.FoundingSeats then
				seat = nil
				return list
			end
			table.insert(list, userId)
			seat = #list
			roster = list
			return list
		end)
	end)
	publishCount()
	return seat
end

local function ownsPass(userId: number, passId: number): boolean
	if passId == 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	end)
	return ok and owns == true
end

-- resolve the highest tier this player owns, claim a seat if newly a member
local function resolve(player: Player)
	if player.UserId == Config.OwnerUserId then
		player:SetAttribute("Seat", 1)
		player:SetAttribute("Tier", "CROWN")
		return
	end

	local isMember = false
	for _, batch in Config.SeatBatches do
		if ownsPass(player.UserId, batch.passId) then
			isMember = true
			break
		end
	end
	if not isMember then
		player:SetAttribute("Tier", "GUEST")
		return
	end

	local seat = claimSeat(player.UserId)
	if not seat then
		-- owns a pass but the roster filled first: honor the purchase anyway
		seat = 0
	end
	if seat > 0 then
		player:SetAttribute("Seat", seat)
	end

	local best = "MEMBER"
	for i = #Config.Tiers, 1, -1 do
		local tier = Config.Tiers[i]
		if tier.passId ~= 0 and ownsPass(player.UserId, tier.passId) then
			best = tier.name
			break
		end
	end
	local prev = player:GetAttribute("Tier")
	player:SetAttribute("Tier", best)
	if prev ~= best and prev ~= nil and prev ~= "GUEST" then
		broadcast(("💎 %s now holds %s."):format(player.DisplayName, best))
	end
end

function Membership.TierIndexOf(player: Player): number
	local name = player:GetAttribute("Tier")
	return Config.TierIndex(typeof(name) == "string" and name :: string or "GUEST")
end

function Membership.IsMember(player: Player): boolean
	return Membership.TierIndexOf(player) >= 2
end

function Membership.PromptJoin(player: Player)
	local batch = Config.ActiveBatch(#roster)
	if not batch or batch.passId == 0 then
		Remotes.Get("Notify"):FireClient(player, "The robes are not yet for sale.", "info")
		return
	end
	if #roster >= Config.FoundingSeats then
		Remotes.Get("Notify"):FireClient(player, "🔒 All 100 robes are granted. Forever.", "bad")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, batch.passId)
end

function Membership.PromptTier(player: Player, tierName: string)
	local tier = Config.TierByName(tierName)
	if not tier or tier.passId == 0 then
		return
	end
	if not Membership.IsMember(player) then
		Membership.PromptJoin(player)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, tier.passId)
end

function Membership.Roster(): { number }
	return roster
end

function Membership.Init(_map: any)
	loadRoster()

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, batch in Config.SeatBatches do
			if passId == batch.passId then
				resolve(player)
				local seat = player:GetAttribute("Seat")
				if typeof(seat) == "number" and seat > 0 then
					broadcast(("👑 %s was granted robe № %d of %d. %d remain."):format(
						player.DisplayName, seat, Config.FoundingSeats,
						math.max(0, Config.FoundingSeats - #roster)
					))
				end
				return
			end
		end
		for _, tier in Config.Tiers do
			if passId == tier.passId then
				resolve(player)
				return
			end
		end
	end)

	-- other servers' purchases arrive here
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message and (message :: any).Data
			if typeof(data) == "table" and data.j ~= game.JobId and typeof(data.t) == "string" then
				Remotes.Get("Notify"):FireAllClients(data.t, "announce")
			end
		end)
	end)

	Remotes.Get("RequestJoin").OnServerEvent:Connect(function(player, tierName)
		if typeof(tierName) == "string" and tierName ~= "" then
			Membership.PromptTier(player, tierName)
		else
			Membership.PromptJoin(player)
		end
	end)

	Players.PlayerAdded:Connect(resolve)
	for _, player in Players:GetPlayers() do
		task.spawn(resolve, player)
	end
end

return Membership
