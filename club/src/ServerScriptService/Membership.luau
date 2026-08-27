--!strict
-- Two things live here, and neither one sells access.
--   THE FOUNDING 100 — the first hundred people to solve their way in, ever.
--   PATRON — a pass that buys gold thread on a robe and a name on a plaque.
-- No rank, no door and no REP is purchasable, by design.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Rep = require(script.Parent.Rep)

local Membership = {}

local ROSTER_KEY = "founding_v1"
local roster: { number } = {}

local function store(): DataStore?
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("MillionsClub")
	end)
	return ok and ds or nil
end

local function publish()
	ReplicatedStorage:SetAttribute("FoundingCount", #roster)
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
	publish()
end

-- Atomic claim: the hundredth seat can only be taken once, across every server.
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
	publish()
	return seat
end

-- Called the moment someone completes initiation.
function Membership.OnInitiated(player: Player)
	local seat = claimSeat(player.UserId)
	if not seat then
		return
	end
	player:SetAttribute("Founding", seat)
	Rep.SetInitiated(player, seat)
	Remotes.Get("Notify"):FireAllClients(
		("Seat %d of %d is taken. %d remain."):format(seat, Config.FoundingSeats, math.max(0, Config.FoundingSeats - #roster)),
		"announce"
	)
end

local function checkPatron(player: Player)
	if Config.PatronPassId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.PatronPassId)
	end)
	if ok and owns then
		player:SetAttribute("Patron", true)
	end
end

function Membership.Init(map: any)
	loadRoster()

	-- the donor plaque: discreet, by the fireplace, and worth no rank at all
	local plaque = Instance.new("Part")
	plaque.Name = "PatronPlaque"
	plaque.Anchored = true
	plaque.CanCollide = false
	plaque.Size = Vector3.new(5, 1.6, 0.3)
	plaque.Position = map.hallCenter + Vector3.new(-20, 4, -24)
	plaque.Color = Color3.fromRGB(20, 19, 23)
	plaque.Material = Enum.Material.Metal
	plaque.Parent = map.folder

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.PatronPassId then
			player:SetAttribute("Patron", true)
			Remotes.Get("Notify"):FireClient(player, "Your thread is gold now. It buys you nothing else.", "good")
		end
	end)

	Players.PlayerAdded:Connect(checkPatron)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPatron, player)
	end

	-- kept so an old client build can't error; patronage is opt-in only
	Remotes.Get("RequestJoin").OnServerEvent:Connect(function(player)
		if Config.PatronPassId ~= 0 and player:GetAttribute("Patron") ~= true then
			MarketplaceService:PromptGamePassPurchase(player, Config.PatronPassId)
		end
	end)
end

function Membership.IsMember(player: Player): boolean
	return Rep.IsInitiated(player)
end

function Membership.Roster(): { number }
	return roster
end

return Membership
