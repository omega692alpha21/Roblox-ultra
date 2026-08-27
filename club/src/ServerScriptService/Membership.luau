--!strict
-- The one product: a single permanent membership, 100 ever. Server-side
-- registry in a DataStore claims seats first-come on verified pass ownership;
-- the door only opens for registered members.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)

local Membership = {}

local ROSTER_KEY = "roster_v1"
local memberSet: { [number]: boolean } = {}
local memberOrder: { number } = {}
local _doorGate: BasePart? = nil
local counterLabel: TextLabel? = nil

local function store(): DataStore?
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("MillionsClub")
	end)
	return ok and ds or nil
end

local function refreshCounter()
	local count = #memberOrder
	if counterLabel then
		counterLabel.Text = count >= Config.MaxMembers
			and "🔒 MEMBERSHIP CLOSED\n100 / 100"
			or ("%d / %d"):format(count, Config.MaxMembers)
	end
	ReplicatedStorage:SetAttribute("MemberCount", count)
end

local function loadRoster()
	local ds = store()
	if not ds then
		return
	end
	pcall(function()
		local roster = ds:GetAsync(ROSTER_KEY)
		if typeof(roster) == "table" then
			memberOrder = roster :: { number }
			for _, id in memberOrder do
				memberSet[id] = true
			end
		end
	end)
	refreshCounter()
end

-- Claim a seat atomically; false if the club is full.
local function claimSeat(userId: number): boolean
	local ds = store()
	if not ds then
		return false
	end
	local claimed = false
	local ok = pcall(function()
		ds:UpdateAsync(ROSTER_KEY, function(old)
			local roster: { number } = typeof(old) == "table" and old :: { number } or {}
			for _, id in roster do
				if id == userId then
					claimed = true
					return roster
				end
			end
			if #roster >= Config.MaxMembers then
				claimed = false
				return roster
			end
			table.insert(roster, userId)
			claimed = true
			memberOrder = roster
			return roster
		end)
	end)
	if claimed then
		memberSet[userId] = true
	end
	refreshCounter()
	return ok and claimed
end

function Membership.IsMember(player: Player): boolean
	return memberSet[player.UserId] == true
end

function Membership.Roster(): { number }
	return memberOrder
end

local function verify(player: Player)
	if memberSet[player.UserId] then
		player:SetAttribute("ClubMember", true)
		return
	end
	if Config.MembershipPassId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.MembershipPassId)
	end)
	if ok and owns then
		if claimSeat(player.UserId) then
			player:SetAttribute("ClubMember", true)
			Remotes.Get("Notify"):FireAllClients(
				("💎 %s has joined MILLIONS CLUB. %d seats remain."):format(player.DisplayName, math.max(0, Config.MaxMembers - #memberOrder)),
				"announce"
			)
		else
			Remotes.Get("Notify"):FireClient(player, "The club is full — all 100 memberships are claimed.", "bad")
		end
	end
end

function Membership.Init(map: { doorGate: BasePart, counterLabel: TextLabel, clubInterior: Vector3 })
	_doorGate = map.doorGate
	counterLabel = map.counterLabel
	loadRoster()

	-- door prompt: members enter, guests get the pitch
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = "MILLIONS CLUB — members only"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = map.doorGate
	prompt.Triggered:Connect(function(player)
		if Membership.IsMember(player) then
			local character = player.Character
			if character then
				character:PivotTo(CFrame.new(map.clubInterior + Vector3.new(0, 2, 0)))
			end
		elseif Config.MembershipPassId ~= 0 and #memberOrder < Config.MaxMembers then
			MarketplaceService:PromptGamePassPurchase(player, Config.MembershipPassId)
		else
			Remotes.Get("Notify"):FireClient(
				player,
				#memberOrder >= Config.MaxMembers and "🔒 Membership is closed. 100/100." or "Membership sales open soon.",
				"info"
			)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.MembershipPassId then
			verify(player)
		end
	end)

	Players.PlayerAdded:Connect(verify)
	for _, player in Players:GetPlayers() do
		task.spawn(verify, player)
	end

	Remotes.Get("RequestJoin").OnServerEvent:Connect(function(player)
		if not Membership.IsMember(player) and Config.MembershipPassId ~= 0 and #memberOrder < Config.MaxMembers then
			MarketplaceService:PromptGamePassPurchase(player, Config.MembershipPassId)
		end
	end)
end

return Membership
