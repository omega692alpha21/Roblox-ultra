--!strict
-- Income tick, cash mutation helpers, leaderstats, collect pads, friend bonus.
-- All cash changes in the game go through AddCash/TrySpend so attributes,
-- leaderstats and signals stay consistent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Students = require(ReplicatedStorage.Config.Students)
local Rebirths = require(ReplicatedStorage.Config.Rebirths)
local Rewards = require(ReplicatedStorage.Config.Rewards)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Remotes = require(ReplicatedStorage.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local EffectsService = require(script.Parent.EffectsService)
local Signals = require(script.Parent.Parent.Signals)

local EconomyService = {}

local uncollected: { [Player]: number } = {}
local periodMult = 1 -- school-day period bonus (e.g. Lunch Rush), set by SchoolClock

function EconomyService.SetPeriodMult(mult: number)
	periodMult = mult
end
local eventMult = 1 -- live-event bonus (e.g. Food Fight), set by EventDirector
function EconomyService.SetEventMult(mult: number)
	eventMult = mult
end
local friendBonus: { [Player]: number } = {}
local collectDebounce: { [Player]: number } = {}

local function ensureLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Cash", "Aura", "Grade" } do
		local v = Instance.new("StringValue")
		v.Name = name
		v.Value = "0"
		v.Parent = stats
	end
	stats.Parent = player
end

local function refreshStats(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	player:SetAttribute("Cash", profile.cash)
	player:SetAttribute("TotalEarned", profile.totalEarned)
	player:SetAttribute("Grade", profile.grade)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Cash") :: StringValue).Value = NumberFormat.Abbreviate(profile.cash);
		(stats:FindFirstChild("Aura") :: StringValue).Value = NumberFormat.Abbreviate(profile.aura);
		(stats:FindFirstChild("Grade") :: StringValue).Value = tostring(profile.grade)
	end
end
EconomyService.RefreshStats = refreshStats

-- Full income multiplier for a player: grade x passes x clique x friends.
-- The uncollected pile. The goal tracker needs it to know when collecting is
-- the most valuable thing you could be doing.
function EconomyService.Pile(player: Player): number
	return uncollected[player] or 0
end

function EconomyService.Multiplier(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 1
	end
	local mult = Rebirths.Multiplier(profile.grade)
	if player:GetAttribute("Pass2x") then
		mult *= 2
	end
	mult *= 1 + (friendBonus[player] or 0)
	return mult
end

-- Raw income per second from the crew (before multipliers).
function EconomyService.BaseIncome(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, member in profile.crew do
		total += Students.IncomeFor(member.id, member.mut, member.star)
	end
	return total
end

-- The richest loaded player wears the bounty crown; robbing them pays bonus aura.
local function updateBounty()
	local richest: Player? = nil
	local richestCash = -1
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile and profile.cash > richestCash then
			richestCash = profile.cash
			richest = player
		end
	end
	for _, player in Players:GetPlayers() do
		local isBounty = player == richest and #Players:GetPlayers() > 1
		if (player:GetAttribute("Bounty") == true) ~= isBounty then
			player:SetAttribute("Bounty", isBounty)
		end
	end
end

function EconomyService.AddCash(player: Player, amount: number, countsAsEarned: boolean?)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.cash += amount
	if countsAsEarned then
		profile.totalEarned += amount
		Signals.Earned:Fire(player, amount)
	end
	refreshStats(player)
end

function EconomyService.TrySpend(player: Player, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or amount < 0 or profile.cash < amount then
		return false
	end
	profile.cash -= amount
	refreshStats(player)
	return true
end

-- Collecting on a rhythm is the core loop, so the loop pays for itself:
-- each collect inside the streak window compounds a bonus, and drifting off
-- resets it. It turns "walk to the pad eventually" into "get back here".
local COLLECT_STREAK_WINDOW = 100
local COLLECT_STREAK_STEP = 0.1
local COLLECT_STREAK_MAX = 5

local lastCollect: { [Player]: number } = {}
local collectStreak: { [Player]: number } = {}

local function bank(player: Player)
	local pile = uncollected[player] or 0
	if pile < 1 then
		return
	end
	uncollected[player] = 0

	local now = os.clock()
	local streak = collectStreak[player] or 0
	if now - (lastCollect[player] or -math.huge) <= COLLECT_STREAK_WINDOW then
		streak = math.min(streak + 1, COLLECT_STREAK_MAX)
	else
		streak = 0
	end
	lastCollect[player] = now
	collectStreak[player] = streak
	player:SetAttribute("CollectStreak", streak)

	local bonus = streak * COLLECT_STREAK_STEP
	local total = math.floor(pile * (1 + bonus))
	EconomyService.AddCash(player, total, true)
	Signals.Collected:Fire(player)
	local plot = PlotService.GetPlot(player)
	if plot then
		plot.pileLabel.Text = "$0"
		EffectsService.CashPopup(plot.collectPad.Position, total)
	end
	if streak > 0 then
		Remotes.Get("Notify"):FireClient(
			player,
			("COLLECT STREAK x%d — +%d%% bonus!"):format(streak + 1, math.floor(bonus * 100)),
			"good"
		)
	end
end

local function updateFriendBonus(player: Player)
	task.spawn(function()
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, isFriend = pcall(function()
					return (player :: any):IsFriendsWith(other.UserId)
				end)
				if ok and isFriend then
					count += 1
				end
			end
		end
		friendBonus[player] = math.min(count * Rewards.FriendIncomeBonus, Rewards.FriendIncomeBonusCap)
	end)
end

function EconomyService.Init()
	Players.PlayerAdded:Connect(function(player)
		ensureLeaderstats(player)
		uncollected[player] = 0
		updateFriendBonus(player)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				updateFriendBonus(other)
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		ensureLeaderstats(player)
		uncollected[player] = uncollected[player] or 0
		updateFriendBonus(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		uncollected[player] = nil
		lastCollect[player] = nil
		collectStreak[player] = nil
		friendBonus[player] = nil
		collectDebounce[player] = nil
	end)
	Signals.ProfileLoaded:Connect(refreshStats)

	-- income tick
	task.spawn(function()
		while true do
			task.wait(GameConfig.IncomeTickSeconds)
			updateBounty()
			for _, player in Players:GetPlayers() do
				if not DataService.IsLoaded(player) then
					continue
				end
				local income = EconomyService.BaseIncome(player)
					* EconomyService.Multiplier(player)
					* periodMult
					* eventMult
					* (GameConfig.EventCashMultiplier or 1)
				player:SetAttribute("Income", math.floor(income))
				local profile = DataService.Get(player)
				if profile then
					profile.lastIncome = income
				end
				if income <= 0 then
					continue
				end
				if player:GetAttribute("PassAutoCollect") then
					EconomyService.AddCash(player, income, true)
				else
					uncollected[player] = (uncollected[player] or 0) + income
					local plot = PlotService.GetPlot(player)
					if plot then
						plot.pileLabel.Text = "$" .. NumberFormat.Abbreviate(uncollected[player] or 0)
					end
				end
			end
		end
	end)

	-- collect pads: touching your own pad banks your pile
	task.defer(function()
		for _, player in Players:GetPlayers() do
			local _ = player
		end
	end)
end

-- Wire one plot's collect pad (called by Server bootstrap after map build).
function EconomyService.WireCollectPad(plot: any)
	plot.collectPad.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character :: any)
		if not player then
			return
		end
		if PlotService.GetPlot(player) ~= plot then
			return
		end
		local now = os.clock()
		if now - (collectDebounce[player] or 0) < 0.5 then
			return
		end
		collectDebounce[player] = now
		bank(player)
	end)
end

return EconomyService
